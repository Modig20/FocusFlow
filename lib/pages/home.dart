import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task.dart';

class HomeScreen extends StatelessWidget {
  final List<Task> tasks;
  final Function(String) onToggleComplete;
  final Function(String) onDeleteTask;

  const HomeScreen({
    super.key,
    required this.tasks,
    required this.onToggleComplete,
    required this.onDeleteTask,
  });

  @override
  Widget build(BuildContext context) {
    return tasks.isEmpty
        ? const Center(
            child: Text(
              'No tasks yet!\nAdd one to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Slidable(
                key: Key(task.id),
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => onDeleteTask(task.id),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.completed ? Colors.grey : Colors.white,
                      ),
                    ),
                    value: task.completed,
                    onChanged: (bool? value) {
                      onToggleComplete(task.id);
                    },
                    activeColor: Colors.blue,
                  ),
                ),
              );
            },
          );
  }
}
