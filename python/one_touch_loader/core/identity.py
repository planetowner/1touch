"""Capology와 Understat가 검증한 이름 비교 규칙을 공유해요."""

import re
import unicodedata
from collections import defaultdict


def normalize_identity_text(value: str) -> str:
    translated = value.casefold().translate(str.maketrans({
        # Yılmaz/Yilmaz·Yazıcı/Yazici처럼 실제 확인한 튀르키예어 표기 차이예요.
        "æ": "ae", "ð": "d", "đ": "dj", "ı": "i", "ł": "l", "ø": "o",
        "œ": "oe", "þ": "th", "ß": "ss", "'": "", "’": "", "­": "",
    }))
    decomposed = unicodedata.normalize("NFKD", translated)
    without_marks = "".join(c for c in decomposed if not unicodedata.combining(c))
    return " ".join(re.sub(r"[^a-z0-9]+", " ", without_marks).split())


def validate_external_id_uniqueness(label: str, mappings: dict, verified_aliases: dict | None = None) -> None:
    """한 내부 ID에 여러 원본 ID를 연결하는 경우는 확인된 별칭만 허용해요."""
    reverse = defaultdict(set)
    for external, internal in mappings.items():
        reverse[internal].add(external)
    aliases = verified_aliases or {}
    duplicates = {internal: sorted(externals) for internal, externals in reverse.items()
                  if len(externals) > 1 and externals != aliases.get(internal)}
    if duplicates:
        raise ValueError(f"{label} IDs have unverified duplicates: {duplicates}")


def reciprocal_identity_matches(db_names: dict, source_names: dict, minimum_overlap: int) -> dict:
    """정확히 같은 이름이 양쪽에서 유일하게 가장 많이 겹치는 팀만 연결해요."""
    scores = {
        (db_id, source_id): len(names & source_names[source_id])
        for db_id, names in db_names.items() for source_id in source_names
    }
    best_db = {}
    for db_id in db_names:
        ranked = sorted((n, sid) for (did, sid), n in scores.items() if did == db_id)
        if ranked and ranked[-1][0] >= minimum_overlap:
            if len(ranked) == 1 or ranked[-1][0] > ranked[-2][0]:
                best_db[db_id] = (ranked[-1][1], ranked[-1][0])
    best_source = {}
    for source_id in source_names:
        ranked = sorted((n, did) for (did, sid), n in scores.items() if sid == source_id)
        if ranked and ranked[-1][0] >= minimum_overlap:
            if len(ranked) == 1 or ranked[-1][0] > ranked[-2][0]:
                best_source[source_id] = ranked[-1][1]
    return {
        db_id: (source_id, overlap)
        for db_id, (source_id, overlap) in best_db.items()
        if best_source.get(source_id) == db_id
    }
