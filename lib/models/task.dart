class Task {
  final String id;
  final String title;
  final String category;
  final String dueDate;
  final List<String> tags;
  bool completed;

  Task({
    required this.id,
    required this.title,
    required this.category,
    required this.dueDate,
    required this.tags,
    this.completed = false,
  });
}
