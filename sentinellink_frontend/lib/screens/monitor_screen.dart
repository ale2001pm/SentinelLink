import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  int _lastAlertVersion = 0;

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    _showAlertIfNeeded(auth);

    final metrics = auth.currentMetrics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SentinelLink - Monitorizacion'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Estado del sistema',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              metrics == null
                  ? 'Esperando primera lectura del monitor...'
                  : 'Ultima actualizacion: ${_formatTimestamp(metrics.timestamp)}',
            ),
            const SizedBox(height: 20),
            _MetricCard(
              title: 'CPU',
              value: metrics?.cpuPercent ?? 0,
              color: Colors.deepOrange,
              subtitle: 'Umbral: 80%',
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'RAM',
              value: metrics?.ramPercent ?? 0,
              color: Colors.blue,
              subtitle: 'Umbral: 90%',
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Disco',
              value: metrics?.diskPercent ?? 0,
              color: Colors.green,
              subtitle: 'Umbral: 90%',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Alertas recientes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(auth.systemAlertMessage ?? 'Sin alertas activas'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertIfNeeded(AuthProvider auth) {
    if (auth.systemAlertVersion == _lastAlertVersion) {
      return;
    }

    _lastAlertVersion = auth.systemAlertVersion;
    final String? alert = auth.systemAlertMessage;
    if (alert == null || alert.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alert),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  final String title;
  final double value;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final double normalized = value.clamp(0, 100) / 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${value.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: normalized,
                backgroundColor: color.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
