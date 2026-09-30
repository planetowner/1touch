enum PushDevicePlatform {
  android('android'),
  ios('ios');

  const PushDevicePlatform(this.apiValue);
  final String apiValue;
}

abstract interface class PushDeviceRepository {
  Future<void> register({
    required String deviceId,
    required String token,
    required PushDevicePlatform platform,
    required String locale,
  });

  Future<void> unregister(String deviceId);
}
