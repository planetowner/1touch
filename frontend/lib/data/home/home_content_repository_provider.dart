import 'package:onetouch/data/home/home_content_repository.dart';
import 'package:onetouch/data/home/home_content_service.dart';

// TODO(backend): Replace this feed-backed implementation when highlights and
// news are available through a supported backend endpoint.
final HomeContentRepository homeContentRepository = HomeContentService();
