class TaskLogEntry {
  final String kind; // "daily" | "extra"
  final String id;
  final String title;
  final DateTime date;
  final DateTime? deadline;
  final bool isCompleted;
  final bool isOverdue;

  const TaskLogEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.date,
    required this.deadline,
    required this.isCompleted,
    required this.isOverdue,
  });

  factory TaskLogEntry.fromJson(Map<String, dynamic> json) => TaskLogEntry(
        kind: json['kind'] as String,
        id: json['id'] as String,
        title: json['title'] as String,
        date: DateTime.parse(json['date'] as String),
        deadline: json['deadline'] == null ? null : DateTime.parse(json['deadline'] as String),
        isCompleted: json['is_completed'] as bool,
        isOverdue: json['is_overdue'] as bool,
      );
}

class TaskLogResponse {
  final int total;
  final int completed;
  final int notCompleted;
  final double completionRate;
  final List<TaskLogEntry> entries;

  const TaskLogResponse({
    required this.total,
    required this.completed,
    required this.notCompleted,
    required this.completionRate,
    required this.entries,
  });

  factory TaskLogResponse.fromJson(Map<String, dynamic> json) => TaskLogResponse(
        total: json['total'] as int,
        completed: json['completed'] as int,
        notCompleted: json['not_completed'] as int,
        completionRate: (json['completion_rate'] as num).toDouble(),
        entries: (json['entries'] as List)
            .map((e) => TaskLogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TemplateHistoryPoint {
  final DateTime date;
  final bool isCompleted;

  const TemplateHistoryPoint({required this.date, required this.isCompleted});

  factory TemplateHistoryPoint.fromJson(Map<String, dynamic> json) => TemplateHistoryPoint(
        date: DateTime.parse(json['date'] as String),
        isCompleted: json['is_completed'] as bool,
      );
}

class TemplateStatsDetail {
  final String templateId;
  final String title;
  final int totalDays;
  final int completedDays;
  final int currentStreak;
  final int longestStreak;
  final double completionRate;
  final List<TemplateHistoryPoint> history;

  const TemplateStatsDetail({
    required this.templateId,
    required this.title,
    required this.totalDays,
    required this.completedDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.completionRate,
    required this.history,
  });

  factory TemplateStatsDetail.fromJson(Map<String, dynamic> json) => TemplateStatsDetail(
        templateId: json['template_id'] as String,
        title: json['title'] as String,
        totalDays: json['total_days'] as int,
        completedDays: json['completed_days'] as int,
        currentStreak: json['current_streak'] as int,
        longestStreak: json['longest_streak'] as int,
        completionRate: (json['completion_rate'] as num).toDouble(),
        history: (json['history'] as List)
            .map((e) => TemplateHistoryPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
