class ChatChannel {
  final int id;
  final String name;
  final bool isPrivate;
  final String channelType; // "GROUP" or "DM"
  final String? dmParticipant1;
  final String? dmParticipant2;

  ChatChannel({
    required this.id,
    required this.name,
    required this.isPrivate,
    this.channelType = 'GROUP',
    this.dmParticipant1,
    this.dmParticipant2,
  });

  bool get isDm => channelType == 'DM';

  String dmOtherUser(String myUsername) {
    if (!isDm) return name;
    if (dmParticipant1?.toLowerCase() == myUsername.toLowerCase()) {
      return dmParticipant2 ?? name;
    }
    return dmParticipant1 ?? name;
  }

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: (json['id'] as num?)?.toInt() ?? (json['channelId'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      isPrivate: json['private'] == true,
      channelType: (json['channelType'] ?? 'GROUP').toString(),
      dmParticipant1: json['dmParticipant1']?.toString(),
      dmParticipant2: json['dmParticipant2']?.toString(),
    );
  }
}
