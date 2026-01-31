import 'package:flutter/material.dart';
import 'dart:async';

enum TaskType { upload, download, opening }

class AppTask {
  final String id;
  final String name;
  final TaskType type;
  double progress; // 0.0 to 1.0
  String status;
  bool isIndeterminate;

  AppTask({
    required this.id,
    required this.name,
    required this.type,
    this.progress = 0.0,
    this.status = 'Starting...',
    this.isIndeterminate = false,
  });
}

class TaskProvider extends ChangeNotifier {
  final Map<String, AppTask> _tasks = {};
  bool _isBusy = false;
  
  // Stream for task completion events
  final _completionController = StreamController<String>.broadcast();
  Stream<String> get completionStream => _completionController.stream;

  List<AppTask> get activeTasks => _tasks.values.toList();
  bool get isBusy => _isBusy;

  void setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  void addTask(AppTask task) {
    _tasks[task.id] = task;
    notifyListeners();
  }

  void updateTask(String id, {double? progress, String? status, bool? isIndeterminate}) {
    if (_tasks.containsKey(id)) {
      if (progress != null) _tasks[id]!.progress = progress;
      if (status != null) _tasks[id]!.status = status;
      if (isIndeterminate != null) _tasks[id]!.isIndeterminate = isIndeterminate;
      notifyListeners();
    }
  }

  void removeTask(String id, {bool success = false}) {
    _tasks.remove(id);
    if (success) {
      _completionController.add(id);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _completionController.close();
    super.dispose();
  }

  bool get hasActiveTasks => _tasks.isNotEmpty;
}
