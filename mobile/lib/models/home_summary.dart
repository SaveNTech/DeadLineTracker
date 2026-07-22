class HomeTaskRef {
  final String kind; // "daily" | "extra"
  final String id;
  final String title;
  final DateTime? deadline;
  final int? priority;
  final bool isOverdue;
  final int? minutesRemaining;

  const HomeTaskRef({
    required this.kind,
    required this.id,
    required this.title,
    required this.deadline,
    required this.priority,
    required this.isOverdue,
    required this.minutesRemaining,
  });

  factory HomeTaskRef.fromJson(Map<String, dynamic> json) => HomeTaskRef(
        kind: json['kind'] as String,
        id: json['id'] as String,
        title: json['title'] as String,
        deadline: json['deadline'] == null ? null : DateTime.parse(json['deadline'] as String),
        priority: json['priority'] as int?,
        isOverdue: json['is_overdue'] as bool,
        minutesRemaining: json['minutes_remaining'] as int?,
      );
}

class HomeSummary {
  final int todayTotal;
  final int todayCompleted;
  final HomeTaskRef? urgent;
  final HomeTaskRef? next;
  final List<HomeTaskRef> weekHighlights;
  final DateTime fetchedAt;

  const HomeSummary({
    required this.todayTotal,
    required this.todayCompleted,
    required this.urgent,
    required this.next,
    required this.weekHighlights,
    required this.fetchedAt,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) => HomeSummary(
        todayTotal: json['today_total'] as int,
        todayCompleted: json['today_completed'] as int,
        urgent: json['urgent'] == null
            ? null
            : HomeTaskRef.fromJson(json['urgent'] as Map<String, dynamic>),
        next: json['next'] == null ? null : HomeTaskRef.fromJson(json['next'] as Map<String, dynamic>),
        weekHighlights: (json['week_highlights'] as List)
            .map((e) => HomeTaskRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        fetchedAt: DateTime.now(),
      );
}
