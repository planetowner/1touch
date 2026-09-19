import 'package:onetouch/data/home/home_content_repository.dart';
import 'package:onetouch/data/home/home_content_service.dart';

// Home highlights come from the Home API. This service remains for BBC news
// and temporary Match Details highlight lookup only.
final HomeContentRepository homeContentRepository = HomeContentService();
