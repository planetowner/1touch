"""검증한 표시 이름과 공급자 이름 구성 요소로 짧은 표기를 만들어요."""
import re
import unicodedata

LOCALES = ('en', 'ko', 'ja', 'zh')
SEPARATORS = {'en': '. ', 'ko': '. ', 'ja': '・', 'zh': '·'}
# 실제 한국어 명단의 '시바사키 가쿠'처럼 성이 먼저인 이름은 그대로 써요.
NATIVE_ORDER_COUNTRIES = {479, 712, 5618}
INITIAL = re.compile(r'^([A-Za-zÀ-ž])\s*[.・·-]\s*(.+)$')


def clean(value):
    return ' '.join((value or '').split())


def comparable(value):
    return ''.join(char for char in unicodedata.normalize('NFKD', clean(value)).casefold()
                   if char.isalnum() and not unicodedata.combining(char))


def words(value):
    return [comparable(word) for word in re.findall(r'\w+', clean(value))]


def has_local_script(value, locale):
    if locale == 'ko':
        return any('\uac00' <= char <= '\ud7a3' for char in value)
    return any('\u3400' <= char <= '\u9fff' or (locale == 'ja' and '\u3040' <= char <= '\u30ff')
               for char in value)


def english_short(display, profile):
    display = clean(display)
    if not display:
        return None, 'missing_display'
    if INITIAL.match(display) or ' ' not in display:
        return display, 'already_compact'
    first, rest = display.split(' ', 1)
    # Dayot/Dayotchanculle처럼 통용 이름이 달라도 공급자의 축약형부터 확인해요.
    common = INITIAL.match(clean(profile.get('common_name')))
    if common and comparable(common[1]) == comparable(first[0]):
        tail = words(common[2])
        if tail and words(display)[-len(tail):] == tail:
            return first[0].upper() + SEPARATORS['en'] + common[2], 'provider_initial_name'
    given = clean(profile.get('firstname'))
    given_starts = {comparable(given.split(' ')[0]), comparable(re.split(r'[\s-]+', given)[0])}
    if not given or comparable(first) not in given_starts:
        # Pepe Reina의 Pepe는 정식 이름과 달라요. 표시된 성이 별도 성 필드에
        # 단어 단위로 있으면 통용 이름의 이니셜을 쓰고, 복합 성은 그대로 둬요.
        family, remainder = words(profile.get('lastname')), words(rest)
        if remainder and any(family[index:index + len(remainder)] == remainder
                             for index in range(len(family) - len(remainder) + 1)):
            return first[0].upper() + SEPARATORS['en'] + rest, 'verified_display_family'
        return None, 'unverified_display_order'
    # 마지막 단어만 고르지 않아 de Jong, ter Stegen, Alexander-Arnold를 보존해요.
    return first[0].upper() + SEPARATORS['en'] + rest, 'initial_and_display_remainder'


def short_names(current, profiles, aliases):
    english, reason = english_short(current['display_name'], profiles['en'])
    values, reasons = {'en': english}, {'en': reason}
    match = INITIAL.match(english or '')
    for locale in LOCALES[1:]:
        display = clean(current.get(f'display_name_{locale}'))
        if not display:
            values[locale], reasons[locale] = None, 'missing_display'
            continue
        override = aliases.get(str(current['player_id']), {}).get(locale)
        if override:
            values[locale], reasons[locale] = override, 'source_verified_alias'
            continue
        initial_name = INITIAL.match(display)
        if initial_name:
            agrees = match and comparable(initial_name[1]) == comparable(match[1])
            values[locale] = match[1] + SEPARATORS[locale] + initial_name[2] if agrees else None
            reasons[locale] = 'existing_initial_name' if agrees else 'initial_conflict'
            continue
        if locale == 'ko':
            if ' ' not in display or current['nationality_id'] in NATIVE_ORDER_COUNTRIES:
                values[locale], reasons[locale] = display, 'keep_single_or_native_order_name'
            elif match and reason in ('initial_and_display_remainder', 'provider_initial_name',
                                      'verified_display_family'):
                values[locale] = match[1] + SEPARATORS[locale] + display.split(' ', 1)[1]
                reasons[locale] = 'initial_and_display_remainder'
            else:
                values[locale], reasons[locale] = None, 'unverified_display_order'
            continue
        profile = profiles[locale]
        given, family = clean(profile.get('firstname')), clean(profile.get('lastname'))
        if current['nationality_id'] in NATIVE_ORDER_COUNTRIES:
            # 이름만 반환된 값은 검증된 축약형으로 등록하지 않아요.
            is_given_only = comparable(display) == comparable(given) != comparable(family)
            values[locale] = None if is_given_only else display
            reasons[locale] = 'given_name_only' if is_given_only else 'keep_native_order_name'
            continue
        if not match:
            values[locale] = display if english and ' ' not in english else None
            reasons[locale] = 'keep_mononym' if values[locale] else 'unverified_english_short_name'
            continue
        if family and comparable(display) == comparable(family):
            values[locale], reasons[locale] = display, 'already_family_name'
            continue
        common = INITIAL.match(clean(profile.get('common_name')))
        if common and comparable(common[1]) == comparable(match[1]) and has_local_script(common[2], locale):
            values[locale] = match[1] + SEPARATORS[locale] + common[2]
            reasons[locale] = 'provider_initial_name'
            continue
        # 공급자가 성을 별도 제공하고 영문 축약형의 나머지와 연결될 때만 사용해요.
        english_family = comparable(profiles['en'].get('lastname'))
        tail = comparable(match[2])
        if family and has_local_script(family, locale) and tail == english_family:
            values[locale] = match[1] + SEPARATORS[locale] + family
            reasons[locale] = 'provider_family_name'
            continue
        # 표시 이름의 구분자만 자르며, 현지어 성 내부의 중점·공백은 유지해요.
        split = re.split(r'[\s・·]+', display, maxsplit=1)
        given_first = re.split(r'[\s・·]+', given)[0]
        if len(split) == 2 and given_first and comparable(split[0]) == comparable(given_first):
            values[locale] = match[1] + SEPARATORS[locale] + split[1]
            reasons[locale] = 'verified_local_given_prefix'
        else:
            values[locale], reasons[locale] = None, 'unverified_local_name_parts'
    return values, reasons
