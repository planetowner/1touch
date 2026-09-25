import 'package:flutter/widgets.dart';

// 저장된 성·이름의 의미는 유지하고, 앱 언어에 따라 입력과 표시 순서만 바꿔요.
bool _familyNameFirst(Locale locale) =>
    const {'ko', 'ja', 'zh'}.contains(locale.languageCode);

List<T> orderedUserNameParts<T>({
  required Locale locale,
  required T firstName,
  required T lastName,
}) =>
    _familyNameFirst(locale) ? [lastName, firstName] : [firstName, lastName];

String userNameLabel({
  required Locale locale,
  required String firstName,
  required String lastName,
}) =>
    orderedUserNameParts(
      locale: locale,
      firstName: firstName,
      lastName: lastName,
    ).join(_familyNameFirst(locale) ? '' : ' ');
