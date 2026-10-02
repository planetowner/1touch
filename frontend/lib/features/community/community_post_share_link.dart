Uri communityPostShareUri(int postId) {
  if (postId < 1) throw ArgumentError.value(postId, 'postId');
  return Uri.https('1touch.football', '/community/$postId');
}
