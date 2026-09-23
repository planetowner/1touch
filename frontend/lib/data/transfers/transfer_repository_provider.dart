import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/transfers/api/api_transfer_repository.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';

final TransferRepository transferRepository = ApiTransferRepository(
  api: apiClient,
);
