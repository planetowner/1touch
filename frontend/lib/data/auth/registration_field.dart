enum RegistrationField {
  username('username'),
  displayName('display_name'),
  email('email');

  const RegistrationField(this.apiValue);

  final String apiValue;
}
