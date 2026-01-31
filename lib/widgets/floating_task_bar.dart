import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import 'package:gap/gap.dart';

class FloatingTaskBar extends StatelessWidget {
  const FloatingTaskBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        if (!provider.hasActiveTasks) return const SizedBox.shrink();

        final tasks = provider.activeTasks;
        
        return Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: tasks.map((task) => _TaskItem(task: task)).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _TaskItem extends StatelessWidget {
  final AppTask task;

  const _TaskItem({required this.task});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (task.type) {
      case TaskType.upload:
        icon = Icons.cloud_upload_outlined;
        color = Colors.blueAccent;
        break;
      case TaskType.download:
        icon = Icons.cloud_download_outlined;
        color = Colors.greenAccent;
        break;
      case TaskType.opening:
        icon = Icons.open_in_new_outlined;
        color = Colors.orangeAccent;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.status,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (task.progress >= 0 && task.progress < 1) ...[
                          Text(
                            " • ",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          Text(
                            '${(task.progress * 100).toInt()}%',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 18),
                onPressed: () {
                  Provider.of<TaskProvider>(context, listen: false).removeTask(task.id);
                },
              ),
            ],
          ),
          if (task.progress >= 0 && task.progress < 1) ...[
            const Gap(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.isIndeterminate ? null : task.progress,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
