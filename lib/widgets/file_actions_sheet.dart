import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/file_item.dart';
import '../config/theme.dart';
import '../utils/file_icons.dart';
import '../utils/formatters.dart';

class FileActionsSheet extends StatelessWidget {
  final FileItem item;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onRename;
  final VoidCallback onCopy;
  final VoidCallback onDuplicate;
  final VoidCallback? onPaste;
  final VoidCallback onMove;
  final VoidCallback onInfo;
  final VoidCallback onDelete;

  const FileActionsSheet({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onDownload,
    required this.onRename,
    required this.onCopy,
    required this.onDuplicate,
    this.onPaste,
    required this.onMove,
    required this.onInfo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSecondary.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppTheme.glassLight,
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),

              // File Info Header (Premium card look)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.glassLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: FileIcons.getBackgroundColor(
                          item.extension ?? '',
                          item.isFolder,
                        ).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        FileIcons.getIconForFileType(
                          item.extension ?? '',
                          item.isFolder,
                        ),
                        color: FileIcons.getColorForFileType(
                          item.extension ?? '',
                          item.isFolder,
                        ),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Name and Meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getMetaText(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Actions List grouped like iOS
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.glassLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _ActionItem(
                        icon: Icons.open_in_new_rounded,
                        label: 'Open',
                        onTap: () {
                          Navigator.pop(context);
                          onOpen();
                        },
                      ),
                      const Divider(height: 0.5),
                      if (item.isFile) ...[
                        const Divider(height: 0.5),
                        _ActionItem(
                          icon: Icons.arrow_circle_down_rounded,
                          label: 'Download',
                          onTap: () {
                            Navigator.pop(context);
                            onDownload();
                          },
                        ),
                      ],
                      const Divider(height: 0.5),
                      _ActionItem(
                        icon: Icons.drive_file_rename_outline_rounded,
                        label: 'Rename',
                        onTap: () {
                          Navigator.pop(context);
                          onRename();
                        },
                      ),
                      const Divider(height: 0.5),
                      _ActionItem(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onTap: () {
                          Navigator.pop(context);
                          onCopy();
                        },
                      ),
                      const Divider(height: 0.5),
                      _ActionItem(
                        icon: Icons.control_point_duplicate_rounded,
                        label: 'Duplicate',
                        onTap: () {
                          Navigator.pop(context);
                          onDuplicate();
                        },
                      ),
                      const Divider(height: 0.5),
                      if (onPaste != null) ...[
                        _ActionItem(
                          icon: Icons.paste_rounded,
                          label: 'Paste Here',
                          onTap: () {
                            Navigator.pop(context);
                            onPaste?.call();
                          },
                        ),
                        const Divider(height: 0.5),
                      ],
                      _ActionItem(
                        icon: Icons.folder_copy_rounded,
                        label: 'Move',
                        onTap: () {
                          Navigator.pop(context);
                          onMove();
                        },
                      ),
                      const Divider(height: 0.5),
                      _ActionItem(
                        icon: Icons.info_outline_rounded,
                        label: 'Details',
                        onTap: () {
                          Navigator.pop(context);
                          onInfo();
                        },
                      ),
                      const Divider(height: 0.5),
                      _ActionItem(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        isDanger: true,
                        onTap: () {
                          Navigator.pop(context);
                          onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMetaText() {
    if (item.isFolder) {
      return Formatters.formatItemCount(item.itemCount ?? 0);
    } else {
      final size = item.sizeBytes != null
          ? Formatters.formatFileSize(item.sizeBytes!)
          : '';
      final date = Formatters.formatDate(item.modifiedDate);
      return '$size · $date';
    }
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppTheme.danger : AppTheme.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.accentPrimary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
              Icon(
                icon,
                color: color,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
