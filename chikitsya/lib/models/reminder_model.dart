class Reminder {
  final int id;
  final String title;
  final DateTime time;
  final bool isCritical;
  final String? dosage;
  final bool isCompleted;

  Reminder({
    required this.id,
    required this.title,
    required this.time,
    required this.isCritical,
    this.dosage,
    this.isCompleted = false,
  });

  Reminder copyWith({
    int? id,
    String? title,
    DateTime? time,
    bool? isCritical,
    String? dosage,
    bool? isCompleted,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      isCritical: isCritical ?? this.isCritical,
      dosage: dosage ?? this.dosage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
