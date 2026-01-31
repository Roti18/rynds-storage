import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../config/api_config.dart';
import '../data/file_repository.dart';
import '../models/file_item.dart';
import '../providers/task_provider.dart';

class FileTaskService {
  static final FileTaskService _instance = FileTaskService._internal();
  factory FileTaskService() => _instance;
  FileTaskService._internal();

  bool _isInitialized = false;
  late TaskProvider _taskProvider;

  void initialize(TaskProvider provider) {
    if (_isInitialized) return;
    _isInitialized = true;
    _taskProvider = provider;

    FileDownloader().configure(
      globalConfig: [
        (Config.requestTimeout, const Duration(seconds: 100)),
      ],
      androidConfig: [
        (Config.forceFailPostOnBackgroundChannel, false),
      ],
    ).then((_) {
      // Request notification permissions for Android 13+
      FileDownloader().permissions.request(PermissionType.notifications);

      FileDownloader().updates.listen((update) {
        debugPrint('Downloader Update: ${update.task.taskId} - ${update.toString()}');
        
        switch (update) {
          case TaskProgressUpdate():
            debugPrint('Progress for ${update.task.taskId}: ${update.progress}');
            _taskProvider.updateTask(
              update.task.taskId,
              progress: update.progress,
              status: _getStatusText(update.task, update.progress),
              isIndeterminate: update.expectedFileSize == -1,
            );
            break;
          case TaskStatusUpdate():
            debugPrint('Status change for ${update.task.taskId}: ${update.status}');
            if (update.status == TaskStatus.complete) {
              if (update.task.group == 'opening') {
                _openDownloadedFile(update.task);
              } else if (update.task is DownloadTask) {
                // Move regular downloads to public Downloads folder
                FileDownloader().moveToSharedStorage(update.task as DownloadTask, SharedStorage.downloads).then((path) {
                  debugPrint('File moved to shared storage: $path');
                });
              }
              _taskProvider.removeTask(update.task.taskId, success: true);
            } else if (update.status == TaskStatus.failed || update.status == TaskStatus.canceled) {
              debugPrint('Task ${update.task.taskId} FAILED: ${update.status}');
              _taskProvider.removeTask(update.task.taskId, success: false);
            }
            break;
        }
      });
    });
  }

  String _getStatusText(Task task, double progress) {
    if (task.group == 'opening') return 'Preparing file... ${(progress * 100).toInt()}%';
    if (task is UploadTask) return 'Uploading... ${(progress * 100).toInt()}%';
    return 'Downloading... ${(progress * 100).toInt()}%';
  }

  Future<void> uploadFile(String storage, String path, File file) async {
    final fileName = p.basename(file.path);
    
    // background_downloader requires files to be in a managed directory (BaseDirectory)
    // So we copy the selected file to a temporary upload folder first
    final tempDir = await getTemporaryDirectory();
    final uploadTempDir = Directory(p.join(tempDir.path, 'upload_queue'));
    if (!await uploadTempDir.exists()) {
      await uploadTempDir.create(recursive: true);
    }
    
    final tempFile = await file.copy(p.join(uploadTempDir.path, fileName));

    final task = UploadTask(
      url: Uri.parse(ApiConfig.upload).replace(queryParameters: {
        'storage': storage,
        'path': path,
      }).toString(),
      filename: fileName, 
      baseDirectory: BaseDirectory.temporary,
      directory: 'upload_queue',
      headers: {'Authorization': 'Bearer ${ApiFileRepository.token}'},
      fileField: 'file',
      taskId: 'upload_${DateTime.now().millisecondsSinceEpoch}',
      updates: Updates.statusAndProgress,
      notificationConfig: TaskNotificationConfig(
        taskRunning: const TaskNotification('Uploading', '{filename}'),
        taskComplete: const TaskNotification('Upload finished', '{filename}'),
        taskFailed: const TaskNotification('Upload failed', '{filename}'),
        progressBar: true,
      ),
    );

    _taskProvider.addTask(AppTask(
      id: task.taskId,
      name: fileName,
      type: TaskType.upload,
      status: 'Ready to upload...',
      progress: 0.0,
    ));

    await FileDownloader().enqueue(task);
  }

  Future<void> downloadFile(String storage, FileItem item) async {
    final downloadUrl = Uri.parse(ApiConfig.download).replace(queryParameters: {
      'storage': storage,
      'path': item.path,
    }).toString();
    
    debugPrint('ENQUEUING DOWNLOAD: $downloadUrl');

    final task = DownloadTask(
      url: downloadUrl,
      filename: item.name,
      baseDirectory: BaseDirectory.applicationDocuments, 
      headers: {'Authorization': 'Bearer ${ApiFileRepository.token}'},
      taskId: 'download_${DateTime.now().millisecondsSinceEpoch}',
      updates: Updates.statusAndProgress,
      allowPause: true,
      notificationConfig: TaskNotificationConfig(
        taskRunning: const TaskNotification('Downloading', '{filename}'),
        taskComplete: const TaskNotification('Download finished', '{filename}'),
        taskFailed: const TaskNotification('Download failed', '{filename}'),
        taskPaused: const TaskNotification('Paused', '{filename}'),
        progressBar: true,
      ),
    );

    _taskProvider.addTask(AppTask(
      id: task.taskId,
      name: item.name,
      type: TaskType.download,
      status: 'Starting download...',
      progress: 0.0,
    ));

    await FileDownloader().enqueue(task);
  }

  Future<void> downloadAndOpenFile(String storage, FileItem item) async {
    final downloadUrl = Uri.parse(ApiConfig.download).replace(queryParameters: {
      'storage': storage,
      'path': item.path,
    }).toString();

    final task = DownloadTask(
      url: downloadUrl,
      filename: item.name,
      baseDirectory: BaseDirectory.temporary, 
      directory: 'temp_opens',
      headers: {'Authorization': 'Bearer ${ApiFileRepository.token}'},
      taskId: 'open_${DateTime.now().millisecondsSinceEpoch}',
      group: 'opening',
      updates: Updates.statusAndProgress,
      notificationConfig: TaskNotificationConfig(
        taskRunning: const TaskNotification('Preparing file', '{filename}'),
        taskComplete: const TaskNotification('Ready to open', '{filename}'),
        taskFailed: const TaskNotification('Failed to prepare', '{filename}'),
        progressBar: true,
      ),
    );

    // Get exact file path using manual resolver
    final filePath = await _getFilePath(task);
    
    // If file already exists locally, just open it
    if (await File(filePath).exists()) {
      debugPrint('File already exists at $filePath, opening directly.');
      _openDownloadedFile(task);
      return;
    }

    _taskProvider.addTask(AppTask(
      id: task.taskId,
      name: item.name,
      type: TaskType.opening,
      status: 'Downloading to open...',
      progress: 0.0,
    ));

    await FileDownloader().enqueue(task);
  }

  Future<void> _openDownloadedFile(Task task) async {
    final taskProvider = _taskProvider;
    final taskId = 'open_ui_${task.taskId}';
    
    taskProvider.addTask(AppTask(
      id: taskId,
      name: task.filename,
      type: TaskType.opening,
      status: 'Opening file...',
      progress: 1.0,
    ));

    try {
      final filePath = await _getFilePath(task);
      debugPrint('Attempting to open file at: $filePath');
      
      if (!await File(filePath).exists()) {
        taskProvider.updateTask(taskId, status: 'Error: File not found after download');
        Future.delayed(const Duration(seconds: 5), () => taskProvider.removeTask(taskId));
        return;
      }

      final result = await OpenFilex.open(filePath);
      debugPrint('OpenFilex result: ${result.type}');

      String statusText;
      if (result.type == ResultType.done) {
        statusText = 'File opened with system';
      } else if (result.type == ResultType.noAppToOpen) {
        statusText = 'No app found to open this file';
      } else {
        statusText = 'Failed to open: ${result.message}';
      }

      taskProvider.updateTask(taskId, status: statusText);

      // Keep it visible for 8 seconds
      Future.delayed(const Duration(seconds: 8), () {
        taskProvider.removeTask(taskId);
      });
    } catch (e) {
      debugPrint('Error triggering open: $e');
      taskProvider.updateTask(taskId, status: 'Error: Could not trigger open');
      Future.delayed(const Duration(seconds: 5), () {
        taskProvider.removeTask(taskId);
      });
    }
  }

  // Manual path resolver to avoid library issues
  Future<String> _getFilePath(Task task) async {
    if (task is! DownloadTask) return '';
    
    Directory baseDir;
    switch (task.baseDirectory) {
      case BaseDirectory.applicationDocuments:
        baseDir = await getApplicationDocumentsDirectory();
        break;
      case BaseDirectory.temporary:
        baseDir = await getTemporaryDirectory();
        break;
      case BaseDirectory.applicationSupport:
        baseDir = await getApplicationSupportDirectory();
        break;
      case BaseDirectory.applicationLibrary:
        if (Platform.isIOS || Platform.isMacOS) {
          baseDir = await getLibraryDirectory();
        } else {
          baseDir = await getApplicationSupportDirectory();
        }
        break;
      case BaseDirectory.root:
        return p.join(task.directory, task.filename);
    }

    String fullPath = baseDir.path;
    if (task.directory.isNotEmpty) {
      fullPath = p.join(fullPath, task.directory);
    }
    return p.join(fullPath, task.filename);
  }
}
