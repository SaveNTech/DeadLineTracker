import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A tappable circular checkbox with a pop-in animation on completion.
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({
    super.key,
    required this.isCompleted,
    required this.onTap,
    this.accentColor,
  });

  final bool isCompleted;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.success;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted ? color : Colors.transparent,
          border: Border.all(
            color: isCompleted ? color : Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: isCompleted
              ? const Icon(Icons.check, size: 18, color: Colors.white, key: ValueKey('checked'))
              : const SizedBox.shrink(key: ValueKey('unchecked')),
        ),
      ),
    );
  }
}
