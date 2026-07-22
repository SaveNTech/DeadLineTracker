class FinancialGoal {
  final String id;
  final String title;
  final double targetAmount;
  final String currency;
  final DateTime? achievedAt;
  final double currentAmount;
  final double progress;

  const FinancialGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currency,
    required this.achievedAt,
    required this.currentAmount,
    required this.progress,
  });

  bool get isAchieved => achievedAt != null;

  factory FinancialGoal.fromJson(Map<String, dynamic> json) => FinancialGoal(
        id: json['id'] as String,
        title: json['title'] as String,
        targetAmount: double.parse(json['target_amount'].toString()),
        currency: json['currency'] as String,
        achievedAt: json['achieved_at'] == null ? null : DateTime.parse(json['achieved_at'] as String),
        currentAmount: double.parse(json['current_amount'].toString()),
        progress: (json['progress'] as num).toDouble(),
      );
}

class IncomeEntry {
  final String id;
  final double amount;
  final String currency;
  final String source; // "daily_task" | "manual"
  final DateTime entryDate;
  final String? note;
  final String? dailyTaskInstanceId;
  final String? goalId;
  final DateTime createdAt;

  const IncomeEntry({
    required this.id,
    required this.amount,
    required this.currency,
    required this.source,
    required this.entryDate,
    required this.note,
    required this.dailyTaskInstanceId,
    required this.goalId,
    required this.createdAt,
  });

  factory IncomeEntry.fromJson(Map<String, dynamic> json) => IncomeEntry(
        id: json['id'] as String,
        amount: double.parse(json['amount'].toString()),
        currency: json['currency'] as String,
        source: json['source'] as String,
        entryDate: DateTime.parse(json['entry_date'] as String),
        note: json['note'] as String?,
        dailyTaskInstanceId: json['daily_task_instance_id'] as String?,
        goalId: json['goal_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class FinanceSummary {
  final double totalAllTime;
  final double totalThisMonth;
  final double unallocatedAmount;

  const FinanceSummary({
    required this.totalAllTime,
    required this.totalThisMonth,
    required this.unallocatedAmount,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
        totalAllTime: double.parse(json['total_all_time'].toString()),
        totalThisMonth: double.parse(json['total_this_month'].toString()),
        unallocatedAmount: double.parse(json['unallocated_amount'].toString()),
      );
}
