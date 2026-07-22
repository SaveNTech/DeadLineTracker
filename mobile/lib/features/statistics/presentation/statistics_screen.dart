import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../daily_tasks/state/daily_tasks_controller.dart';
import '../state/stats_providers.dart';
import 'template_detail_screen.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _periodDays = 30;
  bool _exporting = false;

  // Date-only (no time-of-day) so this stays equal across rebuilds within the
  // same day — otherwise every rebuild would mint a new DateRange (since
  // DateTime.now() ticks), handing taskLogProvider a new family key each time
  // and never letting it settle (endless "loading").
  DateRange get _range {
    final today = DateTime.now();
    final to = DateTime(today.year, today.month, today.day);
    return DateRange(to.subtract(Duration(days: _periodDays - 1)), to);
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final bytes = await ref.read(statsRepositoryProvider).exportCsv(
            from: _range.from,
            to: _range.to,
          );
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'text/csv',
          name: 'deadlinetracker_export.csv',
        ),
      ]);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logAsync = ref.watch(taskLogProvider(_range));
    final dailyChartAsync = ref.watch(dailyStatsProvider);
    final templatesAsync = ref.watch(dailyTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            tooltip: 'Экспорт в CSV',
            onPressed: _exporting ? null : _exportCsv,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7д')),
                ButtonSegment(value: 30, label: Text('30д')),
                ButtonSegment(value: 90, label: Text('90д')),
              ],
              selected: {_periodDays},
              onSelectionChanged: (s) => setState(() => _periodDays = s.first),
            ),
          ),
          const SizedBox(height: 16),
          logAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (log) => Row(
              children: [
                Expanded(
                  child: _StatBox(label: 'Всего', value: '${log.total}', color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBox(
                    label: 'Выполнено',
                    value: '${log.completed}',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBox(
                    label: 'Не выполнено',
                    value: '${log.notCompleted}',
                    color: AppColors.overdue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Активность за 14 дней', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: dailyChartAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (points) => BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  maxY: 1,
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].completionRate.clamp(0.02, 1.0),
                            color: points[i].completionRate >= 1
                                ? AppColors.success
                                : AppColors.primary,
                            width: 10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Ежедневные привычки', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (templates) {
              if (templates.isEmpty) {
                return Text(
                  'Пока нет ежедневных привычек',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                );
              }
              return Column(
                children: templates
                    .map(
                      (t) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(t.title),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TemplateDetailScreen(templateId: t.id, title: t.title),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Журнал за период', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          logAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const Text('Не удалось загрузить журнал'),
            data: (log) {
              if (log.entries.isEmpty) {
                return Text(
                  'Нет записей за выбранный период',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                );
              }
              return Column(
                children: log.entries
                    .map(
                      (e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          e.isCompleted
                              ? Icons.check_circle_rounded
                              : (e.isOverdue ? Icons.error_rounded : Icons.radio_button_unchecked),
                          color: e.isCompleted
                              ? AppColors.success
                              : (e.isOverdue ? AppColors.overdue : theme.colorScheme.outline),
                        ),
                        title: Text(e.title),
                        subtitle: Text(
                          '${e.date.day}.${e.date.month.toString().padLeft(2, '0')}.${e.date.year} · '
                          '${e.kind == 'daily' ? 'ежедневная' : 'доп.'}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
