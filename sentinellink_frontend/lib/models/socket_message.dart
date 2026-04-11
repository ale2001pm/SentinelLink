class SocketMessage {
  final String type;
  final Map<String, dynamic> data;

  SocketMessage({required this.type, required this.data});

  factory SocketMessage.fromJson(Map<String, dynamic> json) {
    return SocketMessage(
      type: (json['type'] ?? '').toString(),
      data: (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'data': data,
    };
  }
}
