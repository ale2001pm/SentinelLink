class ChatChannel {
  final int id;
  final String name;
  final bool isPrivate;

  ChatChannel({
    required this.id,
    required this.name,
    required this.isPrivate,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      isPrivate: json['private'] == true,
    );
  }
}