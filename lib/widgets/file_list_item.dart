import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/file_item.dart';
import '../config/theme.dart';
import '../utils/file_icons.dart';
import '../utils/formatters.dart';

import '../config/api_config.dart';
import '../data/file_repository.dart';

class FileListItem extends StatelessWidget {
  final FileItem item;
  final String storage; // Added storage param
  final bool isRecent; // To highlight recent items or just debug context
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const FileListItem({
    super.key,
    required this.item,
    required this.storage,
    this.isRecent = false,
    required this.onTap,
    required this.onMoreTap,
  });

  bool get canPreview {
    final ext = (item.extension ?? '').toLowerCase();
    if (ext.isEmpty) return false;
    final normalized = ext.startsWith('.') ? ext : '.$ext';
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp']
        .contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgElevated.withOpacity(0.4), // Use opacity without blur for performance
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.glassLight.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: AppTheme.accentPrimary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // File/Folder Icon or Preview
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FileIcons.getBackgroundColor(
                        item.extension,
                        item.isFolder,
                      ).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias, // Clip image to border radius
                    child: _buildIconOrPreview(),
                  ),
                  const SizedBox(width: 16),
                  // File Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getMetaText(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // More Button (iOS style horizontal dots)
                  IconButton(
                    onPressed: onMoreTap,
                    icon: const Icon(Icons.more_horiz_rounded),
                    color: AppTheme.textTertiary,
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconOrPreview() {
    if (canPreview && !item.isFolder) {
      final uri = Uri.parse(ApiConfig.preview).replace(
        queryParameters: {
          'storage': storage,
          'path': item.path,
          'thumb': 'true',
        },
      );

      final token = ApiFileRepository.token;
      
      return Image.network(
        uri.toString(),
        fit: BoxFit.cover,
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        errorBuilder: (context, error, stackTrace) => _buildIcon(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppTheme.bgElevated,
            child: const Center(
              child: SizedBox(
                width: 15, height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentPrimary),
              ),
            ),
          );
        },
      );
    }
    return Center(child: _buildIcon());
  }

  Widget _buildIcon() {
    return Icon(
      FileIcons.getIconForFileType(
        item.extension,
        item.isFolder,
      ),
      color: FileIcons.getColorForFileType(
        item.extension,
        item.isFolder,
      ),
      size: 26,
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

  String _getDirectoryPath(String fullPath) {
    if (!fullPath.contains('/')) return '/';
    final parts = fullPath.split('/');
    if (parts.length <= 1) return '/';
    parts.removeLast(); // Remove filename
    final dir = parts.join('/');
    return dir.isEmpty ? '/' : dir;
  }
}
