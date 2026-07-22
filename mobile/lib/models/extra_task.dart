class ExtraTask {
  final String id;
  final String title;
  final String? description;
  final DateTime? deadline;
  final int priority; // 1 = low (green), 2 = medium (dark blue), 3 = high (red)
  final bool isCompleted;
  final DateTime? completedAt;
  final int position;
  final bool isOverdue;

  const ExtraTask({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.priority,
    required this.isCompleted,
    required this.completedAt,
    required this.position,
    required this.isOverdue,
  });

  factory ExtraTask.fromJson(Map<String, dynamic> json) => ExtraTask(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        deadline: json['deadline'] == null ? null : DateTime.parse(json['deadline'] as String),
        priority: json['priority'] as int,
        isCompleted: json['is_completed'] as bool,
        completedAt:
            json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
        position: json['position'] as int,
        isOverdue: json['is_overdue'] as bool,
      );
}
