import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/notifications/api/api_push_device_repository.dart';
import 'package:onetouch/data/notifications/push_device_id_store.dart';
import 'package:onetouch/data/notifications/push_device_repository.dart';

final PushDeviceRepository pushDeviceRepository =
    ApiPushDeviceRepository(api: apiClient);
final PushDeviceIdStore pushDeviceIdStore =
    SharedPreferencesPushDeviceIdStore();
