class SystemMetrics {
  final double cpuPercent;
  final double ramPercent;
  final double diskPercent;
  final DateTime timestamp;

  SystemMetrics({
    required this.cpuPercent,
    required this.ramPercent,
    required this.diskPercent,
    required this.timestamp,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(
      (json['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );

    return SystemMetrics(
      cpuPercent: (json['cpuPercent'] as num?)?.toDouble() ?? 0.0,
      ramPercent: (json['ramPercent'] as num?)?.toDouble() ?? 0.0,
      diskPercent: (json['diskPercent'] as num?)?.toDouble() ?? 0.0,
      timestamp: timestamp,
    );
  }
}
