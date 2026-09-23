import 'package:onetouch/data/teams/api/api_team_response.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/data/teams/team_color_palette_2627.dart';

Team teamFromApiJson(Map<String, dynamic> json) =>
    teamFromApiResponse(ApiTeamResponse.fromJson(json));

Team teamFromApiResponse(ApiTeamResponse response) {
  // 색상은 앱의 공통 팔레트를 쓰고, 팀 이름·사진·소속은 API 값을 사용해요.
  return Team(
    teamId: response.teamId,
    name: response.name,
    shortName: response.shortName,
    shortCode: response.shortCode,
    imagePath: response.imagePath,
    primaryColor: teamColorPaletteForName(response.name)?.primary ?? 0xFFD82457,
  );
}
