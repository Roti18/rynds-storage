import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/file_categories.dart';

class CategoryCard extends StatelessWidget {
  final FileCategory category;
  final int fileCount;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.fileCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryName = FileCategoryHelper.getCategoryName(category);
    final categoryIcon = FileCategoryHelper.getCategoryIcon(category);
    final categoryColor = FileCategoryHelper.getCategoryColor(category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.separator.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                categoryIcon,
                color: categoryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              categoryName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$fileCount ${fileCount == 1 ? 'file' : 'files'}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
