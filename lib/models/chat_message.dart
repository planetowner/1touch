class ChatMessage{
  final String messageId;
  final String userId;
  final String username;
  final String text;
  final int timestamp;

  const ChatMessage({
    required this.messageId,
    required this.userId,
    required this.username,
    required this.text,
    required this.timestamp
  });

  factory ChatMessage.fromSnapshot(String key, Map<dynamic, dynamic> data){
    return ChatMessage(
      messageId: key,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? 0,
    );
  }

  String get timeString{
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2,'0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

}