import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/notifications/push_device_id_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('creates one UUID and reuses it across store instances', () async {
    SharedPreferences.setMockInitialValues({});
    final firstStore = SharedPreferencesPushDeviceIdStore();

    final first = await firstStore.readOrCreate();
    final second = await SharedPreferencesPushDeviceIdStore().readOrCreate();

    expect(Uuid.isValidUUID(fromString: first), isTrue);
    expect(second, first);
    expect(await firstStore.read(), first);
  });

  test('replaces an invalid saved device ID', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesPushDeviceIdStore.storageKey: 'invalid',
    });

    final value = await SharedPreferencesPushDeviceIdStore().readOrCreate();

    expect(Uuid.isValidUUID(fromString: value), isTrue);
    expect(value, isNot('invalid'));
  });

  test('read does not create a device ID', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesPushDeviceIdStore();

    expect(await store.read(), isNull);
  });
}
