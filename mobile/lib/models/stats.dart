class DailyStatPoint {
  final DateTime date;
  final int dailyTotal;
  final int dailyCompleted;
  final int extraTotal;
  final int extraCompleted;
  final int total;
  final int completed;

  const DailyStatPoint({
    required this.date,
    required this.dailyTotal,
    required this.dailyCompleted,
    required this.extraTotal,
    required this.extraCompleted,
    required this.total,
    required this.completed,
  });

  factory DailyStatPoint.fromJson(Map<String, dynamic> json) => DailyStatPoint(
        date: DateTime.parse(json['date'] as String),
        dailyTotal: json['daily_total'] as int,
        dailyCompleted: json['daily_completed'] as int,
        extraTotal: json['extra_total'] as int,
        extraCompleted: json['extra_completed'] as int,
        total: json['total'] as int,
        completed: json['completed'] as int,
      );

  double get completionRate => total == 0 ? 0 : completed / total;
}

class StatsSummary {
  final int currentStreak;
  final int longestStreak;
  final int totalTasksCompleted;
  final int daysTracked;

  const StatsSummary({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalTasksCompleted,
    required this.daysTracked,
  });

  factory StatsSummary.fromJson(Map<String, dynamic> json) => StatsSummary(
        currentStreak: json['current_streak'] as int,
        longestStreak: json['longest_streak'] as int,
        totalTasksCompleted: json['total_tasks_completed'] as int,
        daysTracked: json['days_tracked'] as int,
      );
}
