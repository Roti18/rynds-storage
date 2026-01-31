class StorageInfo {
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final String storageName;
  final String path;
  final bool isMounted;

  StorageInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.storageName,
    required this.path,
    this.isMounted = true,
  });

  double get totalGB => totalBytes / (1024 * 1024 * 1024);
  double get usedGB => usedBytes / (1024 * 1024 * 1024);
  double get freeGB => freeBytes / (1024 * 1024 * 1024);

  double get usagePercentage => (usedBytes / totalBytes * 100).clamp(0, 100);

  String get usageText {
    if (totalGB > 100) {
      return '${usedGB.toStringAsFixed(1)} GB of ${totalGB.toStringAsFixed(0)} GB used';
    } else {
      return '${usedGB.toStringAsFixed(2)} GB of ${totalGB.toStringAsFixed(2)} GB used';
    }
  }

  factory StorageInfo.fromJson(Map<String, dynamic> json) {
    return StorageInfo(
      totalBytes: json['total_size'] as int? ?? 0,
      usedBytes: json['used_size'] as int? ?? 0,
      freeBytes: json['free_size'] as int? ?? 0,
      storageName: json['name'] as String? ?? 'Storage',
      path: json['path'] as String? ?? '',
      isMounted: json['is_mounted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_size': totalBytes,
      'used_size': usedBytes,
      'free_size': freeBytes,
      'name': storageName,
      'path': path,
    };
  }
}
