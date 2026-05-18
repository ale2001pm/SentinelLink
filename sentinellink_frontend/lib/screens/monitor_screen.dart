import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../theme/app_theme.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  int _lastAlertVersion = 0;

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
          backgroundColor: AppTheme.critical,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    final String second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Color _getColorForMetric(String metric, double value) {
    switch (metric) {
      case 'cpu':
      case 'ram':
      case 'disk':
        if (value >= 80) return AppTheme.critical;
        if (value >= 60) return AppTheme.warning;
        return AppTheme.online;
      default:
        return AppTheme.online;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    _showAlertIfNeeded(auth);

    final metrics = auth.currentMetrics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor del Sistema'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Estado del Sistema',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  metrics == null
                                      ? 'Esperando conexión...'
                                      : 'Última actualización: ${_formatTimestamp(metrics.timestamp)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            if (metrics != null)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                decoration: BoxDecoration(
                                  color: AppTheme.online.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.online,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('En vivo'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (metrics == null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: <Widget>[
                                  const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryOrange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Conectando al monitor...',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: <Widget>[
                              _MetricCard(
                                title: 'CPU',
                                icon: Icons.speed,
                                value: metrics.cpuPercent,
                                color: _getColorForMetric('cpu',
                                    metrics.cpuPercent),
                                unit: '%',
                              ),
                              const SizedBox(height: 16),
                              _MetricCard(
                                title: 'Memoria RAM',
                                icon: Icons.memory,
                                value: metrics.ramPercent,
                                color: _getColorForMetric('ram',
                                    metrics.ramPercent),
                                unit: '%',
                              ),
                              const SizedBox(height: 16),
                              _MetricCard(
                                title: 'Almacenamiento',
                                icon: Icons.storage,
                                value: metrics.diskPercent,
                                color: _getColorForMetric('disk',
                                    metrics.diskPercent),
                                unit: '%',
                              ),
                              const SizedBox(height: 24),
                              if (auth.systemAlertMessage != null &&
                                  auth.systemAlertMessage!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.critical
                                        .withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: AppTheme.critical,
                                      width: 2,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppTheme.critical,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          auth.systemAlertMessage!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                            color: AppTheme.critical,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.color,
    this.unit = '%',
  });

  final String title;
  final IconData icon;
  final double value;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 12,
                      value: value / 100,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value >= 80
                  ? 'Advertencia: Uso alto'
                  : value >= 60
                      ? 'Precaución: Uso moderado'
                      : 'Normal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
