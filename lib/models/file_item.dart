class FileItem {
  final String id;
  final String name;
  final String type; // 'file' or 'folder'
  final String path;
  final int? sizeBytes;
  final int? itemCount;
  final DateTime modifiedDate;
  final String? extension;
  final List<FileItem>? children;

  FileItem({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    this.sizeBytes,
    this.itemCount,
    required this.modifiedDate,
    this.extension,
    this.children,
  });

  bool get isFolder => type == 'folder';
  bool get isFile => type == 'file';

  factory FileItem.fromJson(Map<String, dynamic> json) {
    final bool isDir = json['is_dir'] as bool? ?? (json['type'] == 'folder');
    final String path = json['path']?.toString() ?? '/';
    
    return FileItem(
      id: path,
      name: json['name']?.toString() ?? 'Unknown',
      type: isDir ? 'folder' : 'file',
      path: path,
      sizeBytes: json['size'] as int? ?? json['sizeBytes'] as int?,
      itemCount: json['item_count'] as int? ?? json['itemCount'] as int?,
      modifiedDate: json['mod_time'] != null 
          ? DateTime.parse(json['mod_time'] as String)
          : json['modifiedDate'] != null 
              ? DateTime.parse(json['modifiedDate'] as String)
              : DateTime.now(),
      extension: json['extension'] as String?,
      children: null, // API not recursive
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'path': path,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (itemCount != null) 'itemCount': itemCount,
      'modifiedDate': modifiedDate.toIso8601String(),
      if (extension != null) 'extension': extension,
      if (children != null)
        'children': children!.map((child) => child.toJson()).toList(),
    };
  }

  FileItem copyWith({
    String? id,
    String? name,
    String? type,
    String? path,
    int? sizeBytes,
    int? itemCount,
    DateTime? modifiedDate,
    String? extension,
    List<FileItem>? children,
  }) {
    return FileItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      path: path ?? this.path,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      itemCount: itemCount ?? this.itemCount,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      extension: extension ?? this.extension,
      children: children ?? this.children,
    );
  }
}
