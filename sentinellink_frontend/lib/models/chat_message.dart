class ChatMessage {
  final int? messageId;
  final int channelId;
  final String channelName;
  final String sender;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.messageId,
    required this.channelId,
    required this.channelName,
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final DateTime parsedTimestamp = DateTime.tryParse((json['timestamp'] ?? '').toString()) ?? DateTime.now();

    return ChatMessage(
      messageId: (json['messageId'] as num?)?.toInt(),
      channelId: (json['channelId'] as num?)?.toInt() ?? 0,
      channelName: (json['channelName'] ?? '').toString(),
      sender: (json['sender'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      timestamp: parsedTimestamp,
    );
  }
}