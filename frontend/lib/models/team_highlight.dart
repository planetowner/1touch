// SQL: team_youtube_sources LEFT JOIN team_highlights_cache
// team_id | team_name | rank_order | title | published_at | source_type | source_ref
//
// source_type is 'playlist' or 'channel_uploads'; source_ref is the YouTube
// playlist / uploads id the club's highlights are pulled from. The cached
// title/publishedAt describe the most recent clips in that source.

class TeamHighlight {
  final int teamId;
  final String teamName;
  final int rankOrder;
  final String title;
  final String publishedAt; // 'YYYY-MM-DD HH:MM:SS'
  final String sourceType;  // 'playlist' | 'channel_uploads'
  final String sourceRef;

  const TeamHighlight({
    required this.teamId,
    required this.teamName,
    required this.rankOrder,
    required this.title,
    required this.publishedAt,
    required this.sourceType,
    required this.sourceRef,
  });

  /// Best-effort YouTube link for the source this clip was pulled from.
  String get youtubeUrl =>
      (sourceType == 'playlist' || sourceRef.startsWith('PL') || sourceRef.startsWith('UU'))
          ? 'https://www.youtube.com/playlist?list=$sourceRef'
          : 'https://www.youtube.com/channel/$sourceRef';

  factory TeamHighlight.fromJson(Map<String, dynamic> json) => TeamHighlight(
        teamId:      json['team_id'] as int,
        teamName:    json['team_name'] as String,
        rankOrder:   json['rank_order'] as int,
        title:       json['title'] as String,
        publishedAt: json['published_at'] as String,
        sourceType:  json['source_type'] as String,
        sourceRef:   json['source_ref'] as String,
      );
}
