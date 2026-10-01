enum CommunityBanReason {
  harassment('harassment', 'harassing or insulting other users'),
  hateSpeech('hate_speech', 'using hate speech'),
  violentLanguage('violent_language', 'using violent or threatening language'),
  spam('spam', 'repeatedly posting spam'),
  disruption('disruption', 'disrupting community activity'),
  personalInformation(
      'personal_information', 'sharing someone else’s personal information'),
  inappropriateContent(
      'inappropriate_content', 'posting inappropriate content'),
  harmfulToMinors(
      'harmful_to_minors', 'posting content that may be harmful to minors'),
  impersonation('impersonation',
      'impersonating another person or organization or misleading others'),
  illegalContent('illegal_content', 'posting or trading illegal content'),
  serviceMisuse('service_misuse', 'misusing the service'),
  guidelinesViolation(
      'guidelines_violation', 'violating the Community Guidelines');

  const CommunityBanReason(this.code, this.messageKey);

  final String code;
  final String messageKey;
}

class CommunityBanStatus {
  const CommunityBanStatus({required this.reason, required this.endsAt});

  // 사유 저장 기능이 생기기 전 제재에는 기록된 사유가 없어요.
  final CommunityBanReason? reason;
  final DateTime endsAt;
}
