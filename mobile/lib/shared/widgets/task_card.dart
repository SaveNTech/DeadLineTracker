import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import 'animated_check.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.title,
    required this.isCompleted,
    required this.isOverdue,
    required this.onToggle,
    required this.onDelete,
    this.subtitle,
    this.index = 0,
    this.priorityColor,
  });

  final String title;
  final String? subtitle;
  final bool isCompleted;
  final bool isOverdue;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final int index;

  /// Small left-edge stripe marking importance (extra tasks only). Kept
  /// separate from the overdue treatment below so the two never get
  /// visually confused with each other.
  final Color? priorityColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isOverdue && !isCompleted ? AppColors.overdue : null;

    return Dismissible(
      key: ValueKey('${title}_$index${identityHashCode(this)}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.overdue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (priorityColor != null && !isCompleted)
                  Container(width: 4, color: priorityColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        AnimatedCheck(
                          isCompleted: isCompleted,
                          onTap: onToggle,
                          accentColor: accent,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  color: isCompleted
                                      ? theme.colorScheme.outline
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: accent ?? theme.colorScheme.outline,
                                    fontWeight: accent != null ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isOverdue && !isCompleted)
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: AppColors.overdue,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 260.ms, delay: (index * 30).ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}
