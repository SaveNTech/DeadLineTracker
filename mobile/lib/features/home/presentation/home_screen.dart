import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/state/auth_controller.dart';
import '../../daily_tasks/state/daily_tasks_controller.dart';
import '../../extra_tasks/state/extra_tasks_controller.dart';
import '../state/stats_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final summaryAsync = ref.watch(statsSummaryProvider);
    final dailyStatsAsync = ref.watch(dailyStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Привет, ${user?.username ?? ''} 👋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statsSummaryProvider);
          ref.invalidate(dailyStatsProvider);
          await ref.read(dailyTasksControllerProvider.notifier).refresh();
          await ref.read(extraTasksControllerProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            summaryAsync.when(
              loading: () => const _StreakCardsSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
              data: (summary) => Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Серия дней',
                      value: '${summary.currentStreak}',
                      color: AppColors.overdue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_events_rounded,
                      label: 'Рекорд',
                      value: '${summary.longestStreak}',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Выполнено',
                      value: '${summary.totalTasksCompleted}',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),
            Text('Активность за 14 дней', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: dailyStatsAsync.when(
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
            ).animate().fadeIn(delay: 150.ms),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCardsSkeleton extends StatelessWidget {
  const _StreakCardsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 2 ? 0 : 12),
            child: Card(
              child: SizedBox(height: 92, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
        ),
      ),
    );
  }
}
