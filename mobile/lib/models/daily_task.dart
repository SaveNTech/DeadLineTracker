class DailyTaskTemplate {
  final String id;
  final String title;
  final String? description;
  final String? dueTime; // "HH:mm:ss"
  final bool isActive;
  final int position;

  const DailyTaskTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.dueTime,
    required this.isActive,
    required this.position,
  });

  factory DailyTaskTemplate.fromJson(Map<String, dynamic> json) => DailyTaskTemplate(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        dueTime: json['due_time'] as String?,
        isActive: json['is_active'] as bool,
        position: json['position'] as int,
      );
}

class DailyTaskInstance {
  final String id;
  final String templateId;
  final String title;
  final String? description;
  final String date; // "YYYY-MM-DD"
  final String? dueTime;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isOverdue;

  const DailyTaskInstance({
    required this.id,
    required this.templateId,
    required this.title,
    required this.description,
    required this.date,
    required this.dueTime,
    required this.isCompleted,
    required this.completedAt,
    required this.isOverdue,
  });

  factory DailyTaskInstance.fromJson(Map<String, dynamic> json) => DailyTaskInstance(
        id: json['id'] as String,
        templateId: json['template_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        date: json['date'] as String,
        dueTime: json['due_time'] as String?,
        isCompleted: json['is_completed'] as bool,
        completedAt:
            json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
        isOverdue: json['is_overdue'] as bool,
      );
}
