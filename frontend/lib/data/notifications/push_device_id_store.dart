import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract interface class PushDeviceIdStore {
  Future<String?> read();
  Future<String> readOrCreate();
}

class SharedPreferencesPushDeviceIdStore implements PushDeviceIdStore {
  SharedPreferencesPushDeviceIdStore({
    SharedPreferences? preferences,
    Uuid uuid = const Uuid(),
  })  : _preferences = preferences,
        _uuid = uuid;

  static const storageKey = 'notifications.live_test.push_device_id.v1';

  SharedPreferences? _preferences;
  final Uuid _uuid;

  Future<SharedPreferences> get _storage async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read() async {
    final saved = (await _storage).getString(storageKey)?.trim();
    return saved != null && Uuid.isValidUUID(fromString: saved) ? saved : null;
  }

  @override
  Future<String> readOrCreate() async {
    final storage = await _storage;
    final saved = await read();
    if (saved != null) return saved;
    final created = _uuid.v4();
    await storage.setString(storageKey, created);
    return created;
  }
}
