String newsLanguageForLocale(String languageCode) {
  // TODO: 중국어·일본어 공급자를 찾으면 zh·ja도 각 언어의 기사로 제공해요.
  return languageCode.toLowerCase().split(RegExp('[-_]')).first == 'ko'
      ? 'ko'
      : 'en';
}
