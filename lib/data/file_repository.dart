import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_item.dart';
import '../models/storage_info.dart';
import '../utils/file_categories.dart';
import '../config/api_config.dart';

/// Abstract repository interface for file operations
abstract class FileRepository {
  Future<List<String>> getAvailableStorages();
  Future<StorageInfo> getStorageInfo(String storage);
  Future<List<FileItem>> getItemsAtPath(String storage, String path, {bool showHidden = false});
  Future<List<FileItem>> getAllFiles(String storage, {bool showHidden = false});
  Future<List<FileItem>> getRecentFiles(String storage, {int limit = 50, int offset = 0});
  Future<void> deleteItem(String storage, String path);
  Future<void> renameItem(String storage, String oldPath, String newName);
  Future<void> copyItem(String storage, String srcPath, String dstPath);
  Future<void> duplicateItem(String storage, String path);
  Future<void> downloadFile(String storage, String path);
  Future<void> createFolder(String storage, String path);
  Future<Map<FileCategory, int>> getCategoryStats(String storage);
  Future<void> triggerReindex();
  Future<void> uploadFile(String storage, String path, File file);
}

/// Real API implementation
class ApiFileRepository implements FileRepository {
  static String? _token;
  static String? get token => _token;

  Future<void> setToken(String token) async {
    _token = token;
    // Removed SharedPreferences persistence to ensure login is required every app start
  }

  Future<bool> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token != null;
  }

  Future<void> clearToken() async {
     _token = null;
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('auth_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  final Map<String, StorageInfo> _storageCache = {};

  @override
  Future<List<String>> getAvailableStorages() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.storages), headers: _headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> storagesData = data['storages'] ?? [];
        
        final List<String> names = [];
        _storageCache.clear();
        
        for (var item in storagesData) {
          final storage = StorageInfo.fromJson(item as Map<String, dynamic>);
          names.add(storage.storageName);
          _storageCache[storage.storageName] = storage;
        }
        return names;
      } else if (response.statusCode == 401) {
        throw Exception('UNAUTHORIZED');
      }
    } catch (e) {
      debugPrint('Error fetching storages: $e');
      if (e.toString().contains('UNAUTHORIZED')) rethrow;
    }
    return []; // Return empty so UI can trigger _handleAuthError
  }

  @override
  Future<StorageInfo> getStorageInfo(String storage) async {
    // If not in cache, refresh the list
    if (!_storageCache.containsKey(storage)) {
      await getAvailableStorages();
    }
    
    return _storageCache[storage] ?? StorageInfo(
      totalBytes: 0,
      usedBytes: 0,
      freeBytes: 0,
      storageName: storage,
      path: '',
    );
  }

  @override
  Future<List<FileItem>> getItemsAtPath(String storage, String path, {bool showHidden = false}) async {
    // Sanitize path for root: backend expects / as default
    final queryPath = (path.isEmpty) ? '/' : path;
    
    final uri = Uri.parse(ApiConfig.files).replace(
      queryParameters: {
        'storage': storage,
        'path': queryPath,
        'show_hidden': showHidden.toString(),
      },
    );
    
    try {
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> data = body['files'] ?? [];
        return data.map((item) => FileItem.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Server Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network/API Error: $e');
    }
  }

  @override
  Future<List<FileItem>> getAllFiles(String storage, {bool showHidden = false}) async {
    final uri = Uri.parse(ApiConfig.files).replace(
      queryParameters: {
        'storage': storage,
        'path': '/',
        'recursive': 'true',
        'show_hidden': showHidden.toString(),
      },
    );
    
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> data = body['files'] ?? [];
        List<FileItem> items = data.map((item) => FileItem.fromJson(item as Map<String, dynamic>)).toList();
        
        // CHECK: proper recursion support?
        // If result has folders but NO items in subfolders (all paths are simple names),
        // and we have folders, it's likely the server ignored 'recursive=true'.
        bool hasFolders = items.any((i) => i.isFolder);
        bool hasNestedItems = items.any((i) => i.path.trim().contains('/') && i.path.trim() != '/' && i.path.split('/').length > 1);
        
        // Heuristic: If we have folders, but no nested paths are returned, assume shallow list.
        // We will then perform manual client-side crawling.
        if (hasFolders && !hasNestedItems) {
           debugPrint('Warning: Server returned shallow list for recursive request.');
           // Fallback: Return what we have. Client-side crawling is removed for performance.
           // Use searchFiles API instead for category views.
        }

        return items;
      }
      return [];
    } catch (e) {
      debugPrint('getAllFiles failed: $e');
      return [];
    }
  }

  Future<Map<FileCategory, int>> getCategoryStats(String storage) async {
     try {
       // Construct stats request
       final body = <String, List<String>>{};
       for(var cat in FileCategory.values) {
          body[cat.name] = FileCategoryHelper.getExtensionsForCategory(cat);
       }

       final uri = Uri.parse(ApiConfig.stats).replace(queryParameters: {'storage': storage});
       final response = await http.post(
         uri, 
         headers: _headers,
         body: json.encode(body),
       );

       if (response.statusCode == 200) {
         final data = json.decode(response.body)['stats'] as Map<String, dynamic>;
         return data.map((key, value) {
            // Find category enum from string name
            final cat = FileCategory.values.firstWhere((e) => e.name == key, orElse: () => FileCategory.others);
            return MapEntry(cat, value as int);
         });
       }
     } catch (e) {
       debugPrint('Stats fetch error: $e');
     }
     return {};
  }
  
  Future<List<FileItem>> searchFiles(String storage, {
    List<String>? extensions, 
    int limit = 100, 
    int offset = 0,
    int? days,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.search).replace(queryParameters: {
         'storage': storage,
         'limit': limit.toString(),
         'offset': offset.toString(),
         if (days != null) 'days': days.toString(),
         if (extensions != null && extensions.isNotEmpty) 'ext': extensions.join(','),
      });

      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List<dynamic> data = body['files'] ?? [];
        return data.map((item) => FileItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
    return [];
  }
  @override
  Future<List<FileItem>> getRecentFiles(String storage, {int limit = 20, int offset = 0}) async {
    try {
      final uri = Uri.parse(ApiConfig.recent).replace(queryParameters: {
         'storage': storage,
         'limit': limit.toString(),
         'offset': offset.toString(),
      });

      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List<dynamic> data = body['files'] ?? [];
        return data.map((item) => FileItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Recent files fetch error: $e');
    }
    return [];
  }

  @override
  Future<void> deleteItem(String storage, String path) async {
    final url = Uri.parse(ApiConfig.delete).replace(
      queryParameters: {
        'storage': storage,
        'path': path,
      },
    );
    final response = await http.delete(url, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete: ${response.body}');
    }
  }

  @override
  Future<void> renameItem(String storage, String oldPath, String newName) async {
    // Calculate new path
    final pathParts = oldPath.split('/');
    pathParts.removeLast();
    final newPath = '${pathParts.join('/')}/$newName';

    final response = await http.put(
      Uri.parse(ApiConfig.rename),
      headers: _headers,
      body: json.encode({
        'storage': storage,
        'old_path': oldPath,
        'new_path': newPath,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to rename: ${response.body}');
    }
  }

  @override
  Future<void> copyItem(String storage, String srcPath, String dstPath) async {
    final response = await http.post(
      Uri.parse(ApiConfig.copy),
      headers: _headers,
      body: json.encode({
        'storage': storage,
        'old_path': srcPath,
        'new_path': dstPath,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to copy: ${response.body}');
    }
  }

  @override
  Future<void> duplicateItem(String storage, String path) async {
    final response = await http.post(
      Uri.parse(ApiConfig.duplicate),
      headers: _headers,
      body: json.encode({
        'storage': storage,
        'path': path,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to duplicate: ${response.body}');
    }
  }

  @override
  Future<void> downloadFile(String storage, String path) async {
    // Just a placeholder for consistency, actual download logic is in UI/Dio
    final url = Uri.parse(ApiConfig.download).replace(
      queryParameters: {
        'storage': storage,
        'path': path,
      },
    );
    debugPrint('Downloading from: $url');
  }

  @override
  Future<void> createFolder(String storage, String path) async {
    final response = await http.post(
      Uri.parse(ApiConfig.folder),
      headers: _headers,
      body: json.encode({
        'storage': storage,
        'path': path,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create folder: ${response.body}');
    }
  }

  @override
  Future<void> triggerReindex() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.reindex), headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('Failed to trigger reindex');
      }
    } catch (e) {
      debugPrint('Reindex trigger error: $e');
    }
  }

  @override
  Future<void> uploadFile(String storage, String path, File file) async {
    final uri = Uri.parse(ApiConfig.upload).replace(queryParameters: {
      'storage': storage,
      'path': path,
    });
    
    // Create multipart request
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    // Remove Content-Type from headers as MultipartRequest sets it automatically
    request.headers.remove('Content-Type');

    // Add file
    final stream = http.ByteStream(file.openRead());
    final length = await file.length();
    
    final multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: file.uri.pathSegments.last, 
    );
    
    request.files.add(multipartFile);

    // Send
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.body}');
    }
  }

  // --- Offline Caching Methods ---

  Future<List<FileItem>> getCachedFiles(String storage, String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cache_files_${storage}_$path';
      final String? jsonString = prefs.getString(key);
      
      if (jsonString != null) {
        final List<dynamic> data = json.decode(jsonString);
        return data.map((item) => FileItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }
    return [];
  }

  Future<void> saveFilesToCache(String storage, String path, List<FileItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cache_files_${storage}_$path';
      // Convert items to JSON compatible list
      final jsonList = items.map((i) => {
        'name': i.name,
        'path': i.path,
        'is_folder': i.isFolder,
        'size': i.sizeBytes,
        'modified': i.modifiedDate.toIso8601String(),
        'extension': i.extension,
        'items': i.itemCount,
      }).toList();
      
      await prefs.setString(key, json.encode(jsonList));
    } catch (e) {
      debugPrint('Cache write error: $e');
    }
  }
}
