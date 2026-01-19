import 'package:flutter/material.dart';
import '../models/reminder_model.dart';
import '../services/database_service.dart';

class ReminderTimelineScreen extends StatefulWidget {
  final List<Reminder>? reminders;

  const ReminderTimelineScreen({super.key, this.reminders});

  @override
  State<ReminderTimelineScreen> createState() => _ReminderTimelineScreenState();
}

class _ReminderTimelineScreenState extends State<ReminderTimelineScreen> {
  late List<Reminder> _reminders;

  @override
  void initState() {
    super.initState();
    _reminders = List.from(widget.reminders ?? []);
    if (_reminders.isEmpty) {
      _loadReminders();
    }
  }

  Future<void> _loadReminders() async {
    try {
      final reminders = await DatabaseService.getReminders();
      setState(() {
        _reminders = reminders;
      });
    } catch (e) {
      print('Error loading reminders: $e');
    }
  }

  Future<void> _toggleReminderCompletion(Reminder reminder) async {
    try {
      final updatedReminder = reminder.copyWith(
        isCompleted: !reminder.isCompleted,
      );
      await DatabaseService.updateReminderCompletion(
        reminder.id,
        updatedReminder.isCompleted,
      );

      setState(() {
        final index = _reminders.indexWhere((r) => r.id == reminder.id);
        if (index != -1) {
          _reminders[index] = updatedReminder;
        }
      });
    } catch (e) {
      print('Error updating reminder completion: $e');
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update reminder status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Today\'s Care Plan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: _reminders.isEmpty ? _buildEmptyState() : _buildReminderList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'No reminders scheduled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your care plan reminders will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderList() {
    // Sort reminders by time
    final sortedReminders = List<Reminder>.from(_reminders)
      ..sort((a, b) => a.time.compareTo(b.time));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedReminders.length,
      itemBuilder: (context, index) {
        final reminder = sortedReminders[index];
        final isLast = index == sortedReminders.length - 1;

        return Container(
          margin: EdgeInsets.only(bottom: isLast ? 0 : 16, left: 20, right: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: reminder.isCompleted
                          ? Colors.green
                          : reminder.isCritical
                          ? Colors.red
                          : Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (reminder.isCompleted
                                      ? Colors.green
                                      : reminder.isCritical
                                      ? Colors.red
                                      : Colors.blue)
                                  .withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(width: 2, height: 60, color: Colors.grey[300]),
                ],
              ),
              const SizedBox(width: 16),
              // Reminder card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: reminder.isCompleted
                        ? Colors.green[50]
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getReminderIcon(reminder.title),
                            color: reminder.isCompleted
                                ? Colors.green
                                : reminder.isCritical
                                ? Colors.red
                                : Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          if (reminder.isCritical)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'CRITICAL',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Checkbox(
                            value: reminder.isCompleted,
                            onChanged: (value) =>
                                _toggleReminderCompletion(reminder),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: reminder.isCompleted
                              ? Colors.grey[600]
                              : Colors.black87,
                          decoration: reminder.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (reminder.dosage != null &&
                          reminder.dosage!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Dosage: ${reminder.dosage}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(reminder.time),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getReminderIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('medication') || lowerTitle.contains('medicine')) {
      return Icons.medication;
    } else if (lowerTitle.contains('exercise') ||
        lowerTitle.contains('activity')) {
      return Icons.directions_run;
    } else if (lowerTitle.contains('check') || lowerTitle.contains('monitor')) {
      return Icons.monitor_heart;
    } else if (lowerTitle.contains('appointment') ||
        lowerTitle.contains('follow')) {
      return Icons.calendar_today;
    } else {
      return Icons.notifications;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(time.year, time.month, time.day);

    if (reminderDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (reminderDate.isAfter(today)) {
      final difference = reminderDate.difference(today).inDays;
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} (in $difference day${difference > 1 ? 's' : ''})';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} (overdue)';
    }
  }
}
