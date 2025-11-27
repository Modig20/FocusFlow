import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  int _minutes = 25;
  int _seconds = 0;
  bool _isRunning = false;
  final _service = FlutterBackgroundService();

  @override
  void initState() {
    super.initState();
    _service.on('update').listen((event) {
      if (!mounted) return;
      setState(() {
        _minutes = (event!['seconds']! ~/ 60);
        _seconds = (event['seconds']! % 60);
        if (event['seconds']! == 0) {
          _isRunning = false;
        }
      });
    });
  }

  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _service.startService();
        _service.invoke('setTimer', {'duration': _minutes * 60 + _seconds});
      } else {
        _service.invoke('stopTimer');
      }
    });
  }

  void _resetTimer() {
    _service.invoke('stopTimer');
    setState(() {
      _isRunning = false;
      _minutes = 25;
      _seconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _toggleTimer,
                child: Text(_isRunning ? 'Pause' : 'Start'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _resetTimer,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
