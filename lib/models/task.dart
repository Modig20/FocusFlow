import 'package:flutter/material.dart';

class Task {
  String id;
  String title;
  String category;
  String dueDate;
  List<String> tags;
  bool completed;
  int urgency; // 1-5, 5 being most urgent
  int importance; // 1-5, 5 being most important

  Task({
    required this.id,
    required this.title,
    required this.category,
    required this.dueDate,
    this.tags = const [],
    this.completed = false,
    this.urgency = 3,
    this.importance = 3,
  });

  // Priority score for sorting (urgency + importance, max 10)
  int get priorityScore => urgency + importance;

  // Get priority label
  String get priorityLabel {
    if (priorityScore >= 8) return 'Critical';
    if (priorityScore >= 6) return 'High';
    if (priorityScore >= 4) return 'Medium';
    return 'Low';
  }

  Color get priorityColor {
    if (priorityScore >= 8) return Colors.red;
    if (priorityScore >= 6) return Colors.orange;
    if (priorityScore >= 4) return Colors.yellow;
    return Colors.green;
  }
}

class WorkSession {
  Task task;
  int minutes;

  WorkSession({required this.task, required this.minutes});
}
