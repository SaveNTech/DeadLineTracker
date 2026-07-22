import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/home_summary.dart';
import '../../auth/state/auth_controller.dart';
import '../../daily_tasks/state/daily_tasks_controller.dart';
import '../../extra_tasks/state/extra_tasks_controller.dart';
import '../state/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Recomputes the "N минут осталось" countdown without refetching from
    // the server — deadlines are known client-side once fetched.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final homeAsync = ref.watch(homeSummaryProvider);
    final streakAsync = ref.watch(statsSummaryProvider);
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
          await ref.read(homeSummaryProvider.notifier).refresh();
          ref.invalidate(statsSummaryProvider);
          await ref.read(dailyTasksControllerProvider.notifier).refresh();
          await ref.read(extraTasksControllerProvider.notifier).refresh();
        },
        child: homeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: FilledButton(
              onPressed: () => ref.read(homeSummaryProvider.notifier).refresh(),
              child: const Text('Повторить'),
            ),
          ),
          data: (summary) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _TodayRing(summary: summary).animate().fadeIn().slideY(begin: 0.08, end: 0),
              const SizedBox(height: 16),
              streakAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (streak) => Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Серия',
                        value: '${streak.currentStreak}',
                        color: AppColors.overdue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.emoji_events_rounded,
                        label: 'Рекорд',
                        value: '${streak.longestStreak}',
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (summary.urgent != null) ...[
                Text('Срочно', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _TaskRefCard(taskRef: summary.urgent!, showCountdown: true, emphasize: true)
                    .animate()
                    .fadeIn(delay: 80.ms),
                const SizedBox(height: 16),
              ],
              if (summary.next != null) ...[
                Text('Следующее', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _TaskRefCard(taskRef: summary.next!, showCountdown: false, emphasize: false)
                    .animate()
                    .fadeIn(delay: 140.ms),
                const SizedBox(height: 16),
              ],
              if (summary.weekHighlights.isNotEmpty) ...[
                Text('Важное на неделю', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: summary.weekHighlights.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        _WeekHighlightCard(taskRef: summary.weekHighlights[index]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayRing extends StatelessWidget {
  const _TodayRing({required this.summary});
  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = summary.todayTotal == 0 ? 0.0 : summary.todayCompleted / summary.todayTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                  Text('${(progress * 100).round()}%', style: theme.textTheme.labelMedium),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Сегодня', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.todayCompleted} из ${summary.todayTotal} выполнено',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _TaskRefCard extends StatelessWidget {
  const _TaskRefCard({required this.taskRef, required this.showCountdown, required this.emphasize});

  final HomeTaskRef taskRef;
  final bool showCountdown;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = taskRef.isOverdue;
    final accent = overdue
        ? AppColors.overdue
        : (taskRef.priority != null
            ? AppColors.priorityColor(taskRef.priority!)
            : AppColors.primary);

    String? countdownLabel;
    if (showCountdown && taskRef.deadline != null) {
      final minutesLeft = taskRef.deadline!.difference(DateTime.now()).inMinutes;
      countdownLabel = minutesLeft < 0
          ? 'Просрочено на ${-minutesLeft} мин'
          : 'Осталось $minutesLeft мин';
    }

    return Card(
      color: emphasize ? accent.withValues(alpha: 0.10) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              taskRef.kind == 'daily' ? Icons.repeat_rounded : Icons.task_alt_rounded,
              color: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    taskRef.title,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (countdownLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      countdownLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekHighlightCard extends StatelessWidget {
  const _WeekHighlightCard({required this.taskRef});
  final HomeTaskRef taskRef;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.priorityColor(taskRef.priority ?? 3);
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(radius: 5, backgroundColor: color),
              Text(
                taskRef.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (taskRef.deadline != null)
                Text(
                  '${taskRef.deadline!.day}.${taskRef.deadline!.month.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
