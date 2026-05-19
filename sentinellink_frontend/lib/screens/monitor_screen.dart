import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor del Sistema'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Cambiar tema',
            onPressed: () => context.read<ThemeController>().toggle(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: const MonitorPanel(),
    );
  }
}

class MonitorPanel extends StatefulWidget {
  const MonitorPanel({super.key});

  @override
  State<MonitorPanel> createState() => _MonitorPanelState();
}

class _MonitorPanelState extends State<MonitorPanel> {
  int _lastAlertVersion = 0;

  late double _cpuSlider;
  late double _ramSlider;
  late double _diskSlider;
  bool _thresholdsDirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthProvider auth = context.read<AuthProvider>();
    if (!_thresholdsDirty) {
      _cpuSlider = auth.cpuThreshold;
      _ramSlider = auth.ramThreshold;
      _diskSlider = auth.diskThreshold;
    }
  }

  void _showAlertIfNeeded(AuthProvider auth) {
    if (auth.systemAlertVersion == _lastAlertVersion) return;
    _lastAlertVersion = auth.systemAlertVersion;
    final String? alert = auth.systemAlertMessage;
    if (alert == null || alert.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    final String h = local.hour.toString().padLeft(2, '0');
    final String m = local.minute.toString().padLeft(2, '0');
    final String s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color _colorForValue(double value, double threshold) {
    if (value >= threshold) return AppTheme.critical;
    if (value >= threshold * 0.75) return AppTheme.warning;
    return AppTheme.online;
  }

  void _applyThresholds(AuthProvider auth) {
    auth.updateThresholds(_cpuSlider, _ramSlider, _diskSlider);
    setState(() => _thresholdsDirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    _showAlertIfNeeded(auth);

    if (!_thresholdsDirty) {
      _cpuSlider = auth.cpuThreshold;
      _ramSlider = auth.ramThreshold;
      _diskSlider = auth.diskThreshold;
    }

    final metrics = auth.currentMetrics;
    final history = auth.metricsHistory;

    return Stack(
      children: <Widget>[
        SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    _buildHeader(context, auth, metrics),
                    const SizedBox(height: 24),
                    if (metrics == null)
                      _buildWaiting(context)
                    else ...<Widget>[
                      _buildMetricCard(
                        context, 'CPU', Icons.speed,
                        metrics.cpuPercent, auth.cpuThreshold,
                      ),
                      const SizedBox(height: 16),
                      _buildMetricCard(
                        context, 'Memoria RAM', Icons.memory,
                        metrics.ramPercent, auth.ramThreshold,
                      ),
                      const SizedBox(height: 16),
                      _buildMetricCard(
                        context, 'Almacenamiento', Icons.storage,
                        metrics.diskPercent, auth.diskThreshold,
                      ),
                      const SizedBox(height: 24),
                      if (history.length >= 2) ...<Widget>[
                        _buildChartCard(context, history),
                        const SizedBox(height: 24),
                      ],
                      _buildThresholdEditor(context, auth),
                      const SizedBox(height: 16),
                      if (auth.systemAlertMessage != null && auth.systemAlertMessage!.isNotEmpty)
                        _buildAlertBox(context, auth),
                    ],
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            onPressed: () {
              auth.sendTestAlert();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notificacion de prueba enviada'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: AppTheme.primaryOrangeForeground,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Prueba'),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth, dynamic metrics) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Estado del Sistema',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metrics == null
                  ? 'Esperando conexion...'
                  : 'Actualizado: ${_formatTimestamp(metrics.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (metrics != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  Widget _buildWaiting(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: <Widget>[
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
              ),
            ),
            const SizedBox(height: 16),
            Text('Conectando al monitor...', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    IconData icon,
    double value,
    double threshold,
  ) {
    final Color color = _colorForValue(value, threshold);
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Umbral: ${threshold.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
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
                      value: (value / 100).clamp(0.0, 1.0),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${value.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value >= threshold
                  ? 'Critico: Por encima del umbral'
                  : value >= threshold * 0.75
                      ? 'Precaucion: Uso moderado-alto'
                      : 'Normal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, List<dynamic> history) {
    final List<FlSpot> cpuSpots = <FlSpot>[];
    final List<FlSpot> ramSpots = <FlSpot>[];
    final List<FlSpot> diskSpots = <FlSpot>[];

    for (int i = 0; i < history.length; i++) {
      final m = history[i];
      cpuSpots.add(FlSpot(i.toDouble(), m.cpuPercent.clamp(0.0, 100.0)));
      ramSpots.add(FlSpot(i.toDouble(), m.ramPercent.clamp(0.0, 100.0)));
      diskSpots.add(FlSpot(i.toDouble(), m.diskPercent.clamp(0.0, 100.0)));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Historial (ultimas ${history.length} lecturas)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _legendDot(AppTheme.primaryOrange, 'CPU'),
                const SizedBox(width: 16),
                _legendDot(Colors.blueAccent, 'RAM'),
                const SizedBox(width: 16),
                _legendDot(AppTheme.online, 'Disco'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (double value) => FlLine(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 25,
                        getTitlesWidget: (double value, TitleMeta meta) => Text(
                          '${value.toInt()}%',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: <LineChartBarData>[
                    _lineBar(cpuSpots, AppTheme.primaryOrange),
                    _lineBar(ramSpots, Colors.blueAccent),
                    _lineBar(diskSpots, AppTheme.online),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _lineBar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildThresholdEditor(BuildContext context, AuthProvider auth) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.tune_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Umbrales de Alerta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _thresholdSlider(
              context, 'CPU', _cpuSlider, AppTheme.primaryOrange,
              (double v) => setState(() {
                _cpuSlider = v;
                _thresholdsDirty = true;
              }),
            ),
            _thresholdSlider(
              context, 'RAM', _ramSlider, Colors.blueAccent,
              (double v) => setState(() {
                _ramSlider = v;
                _thresholdsDirty = true;
              }),
            ),
            _thresholdSlider(
              context, 'Disco', _diskSlider, AppTheme.online,
              (double v) => setState(() {
                _diskSlider = v;
                _thresholdsDirty = true;
              }),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _thresholdsDirty ? () => _applyThresholds(auth) : null,
                icon: const Icon(Icons.check),
                label: const Text('Aplicar umbrales'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thresholdSlider(
    BuildContext context,
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.12),
                inactiveTrackColor: color.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: value,
                min: 10,
                max: 100,
                divisions: 90,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${value.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBox(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.critical.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.critical, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppTheme.critical),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              auth.systemAlertMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.critical,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
