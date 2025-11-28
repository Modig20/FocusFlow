import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/task.dart';

class FocusTimerScreen extends StatefulWidget {
  final List<Task> tasks;

  const FocusTimerScreen({Key? key, required this.tasks}) : super(key: key);

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  // Step 1: Time input state
  int selectedHours = 1;
  int selectedMinutes = 0;

  // Step 2: Task selection state
  List<Task> selectedTasks = [];

  // Step 3: Timer running state
  List<WorkSession>? workPlan;
  int currentMinutes = 25;
  int currentSeconds = 0;
  bool isRunning = false;
  Timer? timer;
  bool notificationsBlocked = false;
  int currentSessionIndex = 0;

  // Tracks which screen to show: 'time' → 'tasks' → 'timer'
  String currentScreen = 'time'; // 'time', 'tasks', or 'timer'

  // Scrollable time picker controllers
  late FixedExtentScrollController hoursController;
  late FixedExtentScrollController minutesController;

  @override
  void initState() {
    super.initState();
    hoursController = FixedExtentScrollController(initialItem: selectedHours);
    minutesController = FixedExtentScrollController(
      initialItem: selectedMinutes,
    );
  }

  @override
  void dispose() {
    hoursController.dispose();
    minutesController.dispose();
    timer?.cancel();
    if (notificationsBlocked) {
      _enableNotifications();
    }
    super.dispose();
  }

  void _blockNotifications() async {
    try {
      const platform = MethodChannel('com.example.focusflow/notifications');
      await platform.invokeMethod('blockNotifications');
      if (mounted) {
        setState(() => notificationsBlocked = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => notificationsBlocked = true);
      }
    }
  }

  void _enableNotifications() async {
    try {
      const platform = MethodChannel('com.example.focusflow/notifications');
      await platform.invokeMethod('enableNotifications');
      if (mounted) {
        setState(() => notificationsBlocked = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => notificationsBlocked = false);
      }
    }
  }

  List<WorkSession> _calculateWorkPlan(List<Task> tasks, int totalMinutes) {
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    List<WorkSession> sessions = [];
    int remainingMinutes = totalMinutes;

    int totalPriorityScore = sortedTasks.fold(
      0,
      (sum, task) => sum + task.priorityScore,
    );

    for (int i = 0; i < sortedTasks.length; i++) {
      final task = sortedTasks[i];
      int allocatedMinutes;

      if (i == sortedTasks.length - 1) {
        allocatedMinutes = remainingMinutes;
      } else {
        allocatedMinutes =
            (totalMinutes * task.priorityScore / totalPriorityScore).round();
        allocatedMinutes = allocatedMinutes < 5 ? 5 : allocatedMinutes;
      }

      if (allocatedMinutes > 0) {
        sessions.add(WorkSession(task: task, minutes: allocatedMinutes));
        remainingMinutes -= allocatedMinutes;
      }
    }

    return sessions;
  }

  Future<void> _startWorkPlan() async {
    if (selectedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one task')),
      );
      return;
    }

    final totalMinutes = (selectedHours * 60) + selectedMinutes;
    if (totalMinutes < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set at least 5 minutes')),
      );
      return;
    }

    List<Task> tasksToPlan = List<Task>.from(selectedTasks);
    if (tasksToPlan.length > 1) {
      final chosenId = await showDialog<String?>(
        context: context,
        builder: (context) {
          String? selectedId = tasksToPlan.first.id;
          return AlertDialog(
            title: const Text('Pick Primary Focus Task'),
            content: StatefulBuilder(
              builder: (context, setDialogState) => SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: tasksToPlan.map((t) {
                    return RadioListTile<String>(
                      value: t.id,
                      groupValue: selectedId,
                      title: Text(t.title),
                      onChanged: (v) => setDialogState(() => selectedId = v),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, selectedId),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (chosenId != null) {
        tasksToPlan.removeWhere((t) => t.id == chosenId);
        tasksToPlan.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
        final primary = selectedTasks.firstWhere((t) => t.id == chosenId);
        tasksToPlan.insert(0, primary);
      } else {
        return;
      }
    }

    setState(() {
      workPlan = _calculateWorkPlan(tasksToPlan, totalMinutes);
      currentSessionIndex = 0;
      if (workPlan!.isNotEmpty) {
        currentMinutes = workPlan![0].minutes;
        currentSeconds = 0;
      }
      currentScreen = 'timer';
    });
  }

  List<Widget> _buildSchedulePreview(bool isDark) {
    final totalMinutes = (selectedHours * 60) + selectedMinutes;
    if (totalMinutes < 5 || selectedTasks.isEmpty) {
      return [
        Text(
          'Set focus time and select tasks',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ];
    }

    final sortedTasks = List<Task>.from(selectedTasks);
    sortedTasks.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    int totalScore = sortedTasks.fold(
      0,
      (sum, task) => sum + task.priorityScore,
    );
    final result = <Widget>[];
    int cumMin = 0;
    for (int i = 0; i < sortedTasks.length; i++) {
      final task = sortedTasks[i];
      int mins = (i == sortedTasks.length - 1)
          ? totalMinutes - cumMin
          : (totalMinutes * task.priorityScore ~/ totalScore);
      if (i < sortedTasks.length - 1) mins = mins < 5 ? 5 : mins;
      cumMin += mins;
      result.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: task.priorityColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      task.priorityLabel,
                      style: TextStyle(fontSize: 10, color: task.priorityColor),
                    ),
                  ],
                ),
              ),
              Text(
                '$mins m',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      );
      if (i < sortedTasks.length - 1) result.add(const SizedBox(height: 4));
    }
    return result;
  }

  void toggleTimer() {
    if (!isRunning) {
      _blockNotifications();
    }
    setState(() {
      isRunning = !isRunning;
      if (isRunning) {
        startTimer();
      } else {
        timer?.cancel();
      }
    });
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (currentSeconds == 0) {
          if (currentMinutes == 0) {
            timer.cancel();
            isRunning = false;

            if (workPlan != null &&
                currentSessionIndex < workPlan!.length - 1) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Session Complete!'),
                  content: Text(
                    'Time to start: ${workPlan![currentSessionIndex + 1].task.title}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          currentSessionIndex++;
                          currentMinutes =
                              workPlan![currentSessionIndex].minutes;
                          currentSeconds = 0;
                          isRunning = true;
                        });
                        startTimer();
                      },
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              );
            } else {
              _enableNotifications();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('All Done!'),
                  content: const Text(
                    'You completed all your work sessions. Great job!',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          workPlan = null;
                          selectedTasks = [];
                          currentMinutes = 25;
                          currentSeconds = 0;
                          currentScreen = 'time';
                        });
                      },
                      child: const Text('Finish'),
                    ),
                  ],
                ),
              );
            }
          } else {
            currentMinutes--;
            currentSeconds = 59;
          }
        } else {
          currentSeconds--;
        }
      });
    });
  }

  void resetTimer() {
    setState(() {
      timer?.cancel();
      isRunning = false;
      if (notificationsBlocked) _enableNotifications();
      workPlan = null;
      selectedTasks = [];
      currentMinutes = 25;
      currentSeconds = 0;
      currentSessionIndex = 0;
      currentScreen = 'time';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final incompleteTasks = widget.tasks.where((t) => !t.completed).toList();

    if (currentScreen == 'time') {
      return _buildTimeSelectionScreen(isDark, incompleteTasks);
    } else if (currentScreen == 'tasks') {
      return _buildTaskSelectionScreen(isDark, incompleteTasks);
    } else {
      return _buildTimerView(isDark);
    }
  }

  // STEP 1: Time Selection Screen
  Widget _buildTimeSelectionScreen(bool isDark, List<Task> incompleteTasks) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Focus Time',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'How long do you want to focus?',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${selectedHours.toString().padLeft(2, '0')}:${selectedMinutes.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Hours',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 180,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ListWheelScrollView.useDelegate(
                                        controller: hoursController,
                                        itemExtent: 40,
                                        physics:
                                            const FixedExtentScrollPhysics(),
                                        onSelectedItemChanged: (index) {
                                          setState(() => selectedHours = index);
                                        },
                                        childDelegate:
                                            ListWheelChildBuilderDelegate(
                                              builder: (context, index) {
                                                if (index < 0 || index >= 25)
                                                  return null;
                                                return Center(
                                                  child: Text(
                                                    '$index',
                                                    style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                );
                                              },
                                              childCount: 25,
                                            ),
                                      ),
                                      IgnorePointer(
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            border: Border.symmetric(
                                              horizontal: BorderSide(
                                                color: Colors.blue.withOpacity(
                                                  0.18,
                                                ),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            ':',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Minutes',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 180,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ListWheelScrollView.useDelegate(
                                        controller: minutesController,
                                        itemExtent: 40,
                                        physics:
                                            const FixedExtentScrollPhysics(),
                                        onSelectedItemChanged: (index) {
                                          setState(
                                            () => selectedMinutes = index,
                                          );
                                        },
                                        childDelegate:
                                            ListWheelChildBuilderDelegate(
                                              builder: (context, index) {
                                                if (index < 0 || index >= 60)
                                                  return null;
                                                return Center(
                                                  child: Text(
                                                    index.toString().padLeft(
                                                      2,
                                                      '0',
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                );
                                              },
                                              childCount: 60,
                                            ),
                                      ),
                                      IgnorePointer(
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            border: Border.symmetric(
                                              horizontal: BorderSide(
                                                color: Colors.blue.withOpacity(
                                                  0.18,
                                                ),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final totalMinutes =
                          (selectedHours * 60) + selectedMinutes;
                      if (totalMinutes < 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please set at least 5 minutes'),
                          ),
                        );
                      } else {
                        setState(() => currentScreen = 'tasks');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Next: Select Tasks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // STEP 2: Task Selection Screen
  Widget _buildTaskSelectionScreen(bool isDark, List<Task> incompleteTasks) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Tasks',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${selectedHours}h ${selectedMinutes}m focus session',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (incompleteTasks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        'No tasks available. Create some tasks first!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...incompleteTasks.map((task) {
                    final isSelected = selectedTasks.contains(task);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedTasks.remove(task);
                          } else {
                            selectedTasks.add(task);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : (isDark
                                      ? const Color(0xFF3A3A3A)
                                      : const Color(0xFFE0E0E0)),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : null,
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: task.priorityColor.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          task.priorityLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: task.priorityColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'U:${task.urgency} I:${task.importance}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 24),
                if (selectedTasks.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Your Schedule',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._buildSchedulePreview(isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => currentScreen = 'time'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startWorkPlan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Start Focus',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerView(bool isDark) {
    final currentSession = workPlan![currentSessionIndex];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Focus Time',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: resetTimer,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Session ${currentSessionIndex + 1} of ${workPlan!.length}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        currentSession.task.priorityColor.withOpacity(0.2),
                        currentSession.task.priorityColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: currentSession.task.priorityColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Current Task',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentSession.task.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: currentSession.task.priorityColor.withOpacity(
                            0.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${currentSession.task.priorityLabel} Priority',
                          style: TextStyle(
                            fontSize: 12,
                            color: currentSession.task.priorityColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (notificationsBlocked) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All notifications blocked',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(125),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${currentMinutes.toString().padLeft(2, '0')}:${currentSeconds.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isRunning ? 'Stay focused!' : 'Paused',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            iconSize: 32,
                            color: Colors.grey,
                            onPressed: resetTimer,
                          ),
                          const SizedBox(width: 24),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                isRunning ? Icons.pause : Icons.play_arrow,
                              ),
                              iconSize: 32,
                              color: Colors.white,
                              onPressed: toggleTimer,
                            ),
                          ),
                          const SizedBox(width: 56),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Work Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                ...workPlan!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final session = entry.value;
                  final isCurrent = index == currentSessionIndex;
                  final isPast = index < currentSessionIndex;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.blue.withOpacity(0.1)
                          : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? Colors.blue
                            : (isDark
                                  ? const Color(0xFF3A3A3A)
                                  : const Color(0xFFE0E0E0)),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isPast
                                ? Colors.green
                                : isCurrent
                                ? Colors.blue
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              isPast ? '✓' : '${index + 1}',
                              style: TextStyle(
                                color: (isPast || isCurrent)
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.task.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                  decoration: isPast
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${session.minutes} min',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: session.task.priorityColor
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      session.task.priorityLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: session.task.priorityColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
