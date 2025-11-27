import 'package:flutter/material.dart';
import '../models/task.dart';

class CreateTaskScreen extends StatefulWidget {
  final Function(Task) onCreateTask;

  const CreateTaskScreen({super.key, required this.onCreateTask});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  String _category = 'Project';
  DateTime _dueDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task Title'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Category:'),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _category,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _category = newValue;
                      });
                    }
                  },
                  items: <String>['Project', 'Study', 'Exercise']
                      .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Due Date:'),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null && pickedDate != _dueDate) {
                      setState(() {
                        _dueDate = pickedDate;
                      });
                    }
                  },
                  child: Text('${_dueDate.toLocal()}'.split(' ')[0]),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                if (_titleController.text.isNotEmpty) {
                  final newTask = Task(
                    id: DateTime.now().toString(),
                    title: _titleController.text,
                    category: _category,
                    dueDate: '${_dueDate.toLocal()}'.split(' ')[0],
                    tags: [], // Add tags if needed
                  );
                  widget.onCreateTask(newTask);
                }
              },
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}
