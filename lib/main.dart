import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/task.dart';
import 'pages/home.dart';
import 'pages/create_task.dart';
import 'pages/timer.dart';
import 'pages/settings.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  Timer? timer;
  int remainingSeconds = 0;

  service.on('setTimer').listen((data) {
    if (data == null) return;
    remainingSeconds = data['duration'];
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        service.invoke('update', {'seconds': remainingSeconds});
      } else {
        timer.cancel();
      }
    });
  });

  service.on('stopTimer').listen((data) {
    timer?.cancel();
    remainingSeconds = 0;
  });
}

Future<void> initializeService() async {
  try {
    final service = FlutterBackgroundService();
    const notificationChannelId = 'focus_flow_channel';

    final channel = AndroidNotificationChannel(
      notificationChannelId,
      'FocusFlow Timer',
      description: 'This channel is used for timer notifications.',
      importance: Importance.high,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'FocusFlow Timer',
        initialNotificationContent: 'Timer is running...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  } catch (e) {
    debugPrint('Service initialization error (non-critical): $e');
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }

    try {
      await initializeService();
    } catch (e) {
      debugPrint('Background service initialization failed: $e');
    }

    runApp(const FocusFlowApp());
  } catch (e, stackTrace) {
    debugPrint('Critical error in main: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(const ErrorApp());
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('App failed to start. Check logs.')),
      ),
    );
  }
}

class FocusFlowApp extends StatefulWidget {
  const FocusFlowApp({super.key});

  @override
  State<FocusFlowApp> createState() => _FocusFlowAppState();
}

class _FocusFlowAppState extends State<FocusFlowApp> {
  bool _isDarkMode = true; // Default to dark mode

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F5),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MainScreen(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Task> _tasks = [];

  final List<String> _screenTitles = [
    'FocusFlow',
    'Create Task',
    'Focus Timer',
    'Settings',
  ];

  void _addTask(Task task) {
    setState(() {
      _tasks.add(task);
    });
  }

  void _deleteTask(String id) {
    setState(() {
      _tasks.removeWhere((task) => task.id == id);
    });
  }

  void _toggleTaskComplete(String id) {
    setState(() {
      final taskIndex = _tasks.indexWhere((task) => task.id == id);
      if (taskIndex != -1) {
        _tasks[taskIndex].completed = !_tasks[taskIndex].completed;
      }
    });
  }

  void _onNavigate(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        tasks: _tasks,
        onToggleComplete: _toggleTaskComplete,
        onDeleteTask: _deleteTask,
      ),
      CreateTaskScreen(
        onCreateTask: (Task task) {
          _addTask(task);
          _onNavigate(0); // Switch to home screen after adding a task
        },
      ),
      const FocusTimerScreen(),
      SettingsScreen(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_screenTitles[_currentIndex])),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 0),
            _buildNavItem(Icons.add_task, 1),
            _buildNavItem(Icons.timer, 2),
            _buildNavItem(Icons.settings, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 28),
      onPressed: () => _onNavigate(index),
    );
  }
}
