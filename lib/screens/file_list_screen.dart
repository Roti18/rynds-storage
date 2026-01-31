import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart'; // clipboard
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../config/theme.dart';
import '../config/api_config.dart';
import '../models/file_item.dart';
import '../models/storage_info.dart';
import '../data/file_repository.dart';
import '../widgets/file_list_item.dart';
import '../widgets/storage_info_bar.dart';
import '../widgets/empty_state.dart';
import '../widgets/category_card.dart';
import '../widgets/file_actions_sheet.dart';
import '../utils/file_categories.dart';
import '../utils/file_icons.dart';
import '../utils/formatters.dart';

import 'file_preview_screen.dart';
import 'login_screen.dart';

class FileListScreen extends StatefulWidget {
  const FileListScreen({super.key});

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  final FileRepository _repository = ApiFileRepository();
  
  String _currentStorage = 'ssd'; 
  List<String> _availableStorages = ['ssd', 'hdd']; // Default
  List<FileItem> _items = [];
  List<FileItem> _recentItems = [];
  StorageInfo? _storageInfo;
  bool _isLoading = true;
  bool _showHidden = false;
  int _activeTab = 1; 
  final ScrollController _scrollController = ScrollController();
  
  String _currentPath = '/';
  final List<String> _pathStack = ['/'];
  FileCategory? _selectedCategory;
  Map<FileCategory, int> _categoryCounts = {};

  // For caching
  List<FileItem>? _cachedAllFiles;

  // Pagination for Recent items
  int _recentOffset = 0;
  final int _pageSize = 20;
  bool _hasMoreRecent = true;
  bool _isListLoadingMore = false;
  bool _hasMoreCategory = true;

  // Clipboard functionality
  FileItem? _copiedItem;
  String? _copiedFromStorage;
  bool _isCutting = false; // logic for "copy" vs "cut" (move)

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_activeTab == 0 && _hasMoreRecent && !_isListLoadingMore) {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreRecent();
      }
    } else if (_selectedCategory != null && _hasMoreCategory && !_isListLoadingMore) {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreCategory();
      }
    }
  }

  Future<void> _loadMoreCategory() async {
    if (_isListLoadingMore || !_hasMoreCategory) return;
    setState(() => _isListLoadingMore = true);

    try {
      final category = _selectedCategory;
      if (category == null) return;
      
      final currentCount = _items.length;
      final exts = FileCategoryHelper.getExtensionsForCategory(category);
      final moreFiles = await (_repository as ApiFileRepository).searchFiles(
        _currentStorage,
        extensions: exts,
        limit: 10,
        offset: currentCount,
      );

      if (mounted) {
        setState(() {
          if (moreFiles.isEmpty) {
            _hasMoreCategory = false;
          } else {
            _items.addAll(moreFiles);
            if (moreFiles.length < 10) _hasMoreCategory = false;
          }
          _isListLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Load more category failed: $e');
      if (mounted) setState(() => _isListLoadingMore = false);
    }
  }

  Future<void> _loadMoreRecent() async {
    if (_isListLoadingMore || !_hasMoreRecent) return;
    setState(() => _isListLoadingMore = true);

    try {
      // Offset should be the current length of items to get the next batch
      final currentCount = _recentItems.length;
      final moreRecent = await _repository.getRecentFiles(_currentStorage, limit: 10, offset: currentCount);
      
      if (mounted) {
        setState(() {
          if (moreRecent.isEmpty) {
            _hasMoreRecent = false;
          } else {
            _recentItems.addAll(moreRecent);
            if (moreRecent.length < 10) _hasMoreRecent = false;
          }
          _isListLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Load more recent failed: $e');
      if (mounted) setState(() => _isListLoadingMore = false);
    }
  }

  Future<void> _checkPermissions() async {
    // Request storage permissions on startup for download/save actions
    if (Platform.isAndroid) {
       if (await Permission.manageExternalStorage.request().isGranted) {
         // Android 11+
       } else if (await Permission.storage.request().isGranted) {
         // Older Android
       }
    }
  }

  Future<void> _loadData({bool forceRefreshAll = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // 0. Fetch available storages once
      if (_availableStorages.isEmpty || _availableStorages.length <= 2) {
        try {
          _availableStorages = await _repository.getAvailableStorages();
          if (_availableStorages.isEmpty) {
            // This might happen if token is invalid but fallback returned empty
            _handleAuthError();
            return;
          }
          if (mounted) {
            if (!_availableStorages.contains(_currentStorage)) {
              _currentStorage = _availableStorages.first;
            }
          }
        } catch (e) {
          debugPrint('Error fetching storages: $e');
        }
      }

      // 1. OFFLINE-FIRST: Try to load from local cache deeply first (Instant UI)
      if (_selectedCategory == null) { // Only valid for folder view
         final cached = await (_repository as ApiFileRepository).getCachedFiles(_currentStorage, _currentPath);
         if (mounted && cached.isNotEmpty && _items.isEmpty) {
            setState(() {
              _items = cached;
              _isLoading = false; // Show cached content immediately
            });
         }
      }

      // 2. Fetch DATA based on View Mode
      if (_activeTab == 0) {
        // TAB 0: Recently Modified (Last 30 days)
        debugPrint('FETCHING RECENT FILES for $_currentStorage...');
        _recentOffset = 0;
        _hasMoreRecent = true;
        final recentFiles = await _repository.getRecentFiles(_currentStorage, limit: _pageSize);
        if (mounted) {
           setState(() {
             _recentItems = recentFiles;
             _isLoading = false;
             if (recentFiles.length < _pageSize) _hasMoreRecent = false;
           });
        }
      } else if (_selectedCategory != null) {
        // TAB 1 (Modified by category): Fetch specific extensions via Search API
        final category = _selectedCategory!;
        debugPrint('FETCHING CATEGORY FILES for $category...');
        _hasMoreCategory = true;
        final exts = FileCategoryHelper.getExtensionsForCategory(category);
        final files = await (_repository as ApiFileRepository).searchFiles(
           _currentStorage, 
           extensions: exts, 
           limit: _pageSize, // 20
           offset: 0
        );
        
        if (mounted) {
           setState(() {
             _items = files;
             _isLoading = false;
             if (files.length < _pageSize) _hasMoreCategory = false;
           });
        }
      } else {
        // TAB 1 (Folder): standard ls
        try {
          final currentLevelItems = await _repository.getItemsAtPath(_currentStorage, _currentPath, showHidden: _showHidden);
          if (mounted) {
             (_repository as ApiFileRepository).saveFilesToCache(_currentStorage, _currentPath, currentLevelItems);
             setState(() {
               _items = currentLevelItems;
               _isLoading = false; 
             });
          }
        } catch (e) {
             debugPrint('Network fetch failed: $e');
        }
      }

      // 3. BACKGROUND: Fetch Stats & Recent for Home View
      if (_currentPath == '/') {
         _repository.getCategoryStats(_currentStorage).then((stats) {
            if (mounted) setState(() => _categoryCounts = stats);
         });
         
         _repository.getRecentFiles(_currentStorage, limit: 12).then((recent) {
            if (mounted) setState(() => _recentItems = recent);
         });
      }
      
      final storageInfo = await _repository.getStorageInfo(_currentStorage);
      if (mounted) {
        setState(() {
          _storageInfo = storageInfo;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('CRITICAL EXCEPTION: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _selectCategory(FileCategory? category) {
    setState(() {
      _selectedCategory = category;
      if (category != null) {
        _currentPath = '/';
        _activeTab = 1; // Switch to Files tab to see results
      }
    });
    _loadData();
  }

  void _triggerManualReindex() async {
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rescanning storage... Please wait.')),
    );
    await _repository.triggerReindex();
    // Beri waktu sebentar buat server mulai scanning
    await Future.delayed(const Duration(seconds: 1));
    _loadData();
  }

  void _navigateToFolder(FileItem folder) {
    setState(() {
      _currentPath = folder.path;
      _pathStack.add(folder.path);
    });
    _loadData();
  }

  Future<bool> _onWillPop() async {
    if (_selectedCategory != null) {
      _selectCategory(null);
      return false;
    }
    if (_pathStack.length > 1) {
      setState(() {
        _pathStack.removeLast();
        _currentPath = _pathStack.last;
      });
      _loadData();
      return false;
    }
    return true;
  }
  
  // --- Handlers ---

  void _handleOpen(FileItem item) async {
    if (item.isFolder) {
      _navigateToFolder(item);
      return;
    }

    // Unified Preview (Photos, Videos, PDF)
    final cat = FileCategoryHelper.getCategoryFromExtension(item.extension);
    if (cat == FileCategory.photos || cat == FileCategory.videos || item.extension?.toLowerCase() == '.pdf') {
      
      List<FileItem> gallery = [];
      if (cat == FileCategory.photos) {
        gallery = _items.where((i) => 
          !i.isFolder && FileCategoryHelper.getCategoryFromExtension(i.extension) == FileCategory.photos
        ).toList();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FilePreviewScreen(
            item: item,
            storage: _currentStorage,
            galleryItems: gallery.isEmpty ? [item] : gallery,
          ),
        ),
      );
      return;
    }

    // Other: Download temp and open
    await _downloadAndOpenFile(item);
  }

  Future<void> _downloadAndOpenFile(FileItem item) async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${item.name}';
      
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening file...')));
      
      final url = Uri.parse(ApiConfig.download).replace(queryParameters: {
          'storage': _currentStorage,
          'path': item.path,
      }).toString();

      await dio.download(
        url,
        tempPath,
        options: Options(headers: {'Authorization': 'Bearer ${ApiFileRepository.token}'}),
      );

      final result = await OpenFilex.open(tempPath);
      if (result.type != ResultType.done) {
        String msg = result.message;
        if (result.type == ResultType.noAppToOpen) {
          msg = 'No app found to open this file. Please install a viewer/editor from Play Store.';
        }
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }

    } catch (e) {
      debugPrint('Error opening file: $e');
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleDownload(FileItem item) async {
    try {
      // Find Downloads folder
      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getExternalStorageDirectory(); 
        }
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }
      
      final savePath = '${downloadDir?.path}/${item.name}';
      
      final dio = Dio();
      final url = Uri.parse(ApiConfig.download).replace(queryParameters: {
          'storage': _currentStorage,
          'path': item.path,
      }).toString();

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...')));

      await dio.download(
        url,
        savePath,
        options: Options(headers: {'Authorization': 'Bearer ${ApiFileRepository.token}'}),
      );

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $savePath')));

    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }


  void _handleRename(FileItem item) {
    final controller = TextEditingController(text: item.name);
    _showCustomDialog(
      title: 'Rename',
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), 
          child: const Text('Cancel')
        ),
        TextButton(
           child: const Text('Rename', style: TextStyle(color: AppTheme.accentPrimary)),
           onPressed: () async {
             Navigator.of(context).pop();
             try {
               await _repository.renameItem(_currentStorage, item.path, controller.text);
               _loadData();
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Success')));
             } catch (e) {
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
             }
           },
        ),
      ],
    );
  }

  void _handleDelete(FileItem item) {
    _showCustomDialog(
      title: 'Delete',
      content: Text('Delete "${item.name}"?', style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), 
          child: const Text('Cancel')
        ),
        TextButton(
           child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
           onPressed: () async {
             Navigator.of(context).pop();
             try {
               await _repository.deleteItem(_currentStorage, item.path);
               _loadData(forceRefreshAll: true);
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
             } catch (e) {
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
             }
           },
        ),
      ],
    );
  }

  void _handleCopy(FileItem item) {
    setState(() {
      _copiedItem = item;
      _copiedFromStorage = _currentStorage;
      _isCutting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied "${item.name}" to clipboard')),
    );
  }

  void _handleDuplicate(FileItem item) async {
    try {
      await _repository.duplicateItem(_currentStorage, item.path);
      _loadData();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duplicated successfully')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _handlePaste() async {
    if (_copiedItem == null || _copiedFromStorage == null) return;

    try {
      final FileItem itemToPaste = _copiedItem!;
      final String storageToPasteFrom = _copiedFromStorage!;
      
      final dstPath = _currentPath == '/' ? '/${itemToPaste.name}' : '$_currentPath/${itemToPaste.name}';
      
      // If same path, it's redundant but we can handle it (maybe add _copy if exists)
      // For now, let's just trigger copyItem
      await _repository.copyItem(storageToPasteFrom, itemToPaste.path, dstPath);
      
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasted successfully')),
      );
      
      // Clear clipboard after paste as requested (just one click)
      setState(() {
        _copiedItem = null;
        _copiedFromStorage = null;
        _isCutting = false;
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _handleCreateFolder() {
    final controller = TextEditingController();
    _showCustomDialog(
      title: 'New Folder',
      content: TextField(
        controller: controller,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Folder Name',
          hintStyle: TextStyle(color: AppTheme.textTertiary),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), 
          child: const Text('Cancel')
        ),
        TextButton(
          child: const Text('Create', style: TextStyle(color: AppTheme.accentPrimary)),
          onPressed: () async {
            Navigator.of(context).pop();
            if (controller.text.isEmpty) return;
            try {
              final newPath = _currentPath == '/' ? '/${controller.text}' : '$_currentPath/${controller.text}';
              await _repository.createFolder(_currentStorage, newPath);
              _loadData(); 
            } catch (e) {
               if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
            }
          },
        ),
      ],
    );
  }

  Future<void> _handleUpload() async {
    try {
      // Allow multiple pick? For now single for simplicity with backend
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false, 
        type: FileType.any, // Allow images, videos, etc.
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Uploading ${result.files.single.name}...')),
           );
        }

        // Use current path as target
        await _repository.uploadFile(_currentStorage, _currentPath, file);

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Upload successful')),
           );
           _loadData(); // Refresh list
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _handleAuthError() {
    if (mounted) {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (_) => LoginScreen()),
         (route) => false,
       );
    }
  }

  void _handleSort() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Name (A-Z)', style: TextStyle(color: AppTheme.textPrimary)),
            leading: const Icon(Icons.sort_by_alpha, color: AppTheme.accentPrimary),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              });
            },
          ),
          ListTile(
            title: const Text('Date (Newest)', style: TextStyle(color: AppTheme.textPrimary)),
            leading: const Icon(Icons.calendar_today, color: AppTheme.accentPrimary),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _items.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
              });
            },
          ),
          ListTile(
            title: const Text('Size (Largest)', style: TextStyle(color: AppTheme.textPrimary)),
            leading: const Icon(Icons.data_usage, color: AppTheme.accentPrimary),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _items.sort((a, b) => (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0));
              });
            },
          ),
        ],
      ),
    );
  }


  void _showCustomDialog({required String title, required Widget content, List<Widget>? actions}) {
    showDialog(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title, 
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: SingleChildScrollView(child: content),
        ),
        actions: actions ?? [
          TextButton(
            onPressed: () => Navigator.of(innerContext).pop(),
            child: const Text('Close', style: TextStyle(color: AppTheme.accentPrimary)),
          ),
        ],
      ),
    );
  }

  void _showFileActions(FileItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) => FileActionsSheet(
        item: item,
        onOpen: () => _handleOpen(item),
        onDownload: () => _handleDownload(item),
        onRename: () => _handleRename(item),
        onCopy: () => _handleCopy(item),
        onDuplicate: () => _handleDuplicate(item),
        onPaste: _copiedItem != null ? _handlePaste : null,
        onMove: () {
          // Implement move logic or show toast
          ScaffoldMessenger.of(bottomSheetContext).showSnackBar(const SnackBar(content: Text('Move feature coming soon')));
        },
        onInfo: () {
             _showCustomDialog(
               title: 'File Details',
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _InfoRow(label: 'Name', value: item.name),
                   const SizedBox(height: 12),
                   _InfoRow(label: 'Type', value: item.isFolder ? 'Folder' : item.extension?.toUpperCase() ?? 'File'),
                   const SizedBox(height: 12),
                   _InfoRow(label: 'Path', value: item.path),
                   const SizedBox(height: 12),
                   _InfoRow(label: 'Size', value: item.sizeBytes != null ? Formatters.formatFileSize(item.sizeBytes!) : '0 bytes'),
                   const SizedBox(height: 12),
                   _InfoRow(label: 'Modified', value: Formatters.formatDate(item.modifiedDate)),
                 ],
               ),
               // Pass null for actions to use the default safe "Close" button
               actions: null,
             );
        },
        onDelete: () => _handleDelete(item),
      ),
    );
  }

  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchModal(
        items: _activeTab == 1 ? _items : _recentItems,
        onItemSelected: (item) {
          Navigator.pop(context);
          if (item.isFolder) {
            _navigateToFolder(item);
          } else {
            _handleOpen(item);
          }
        },
        onMoreTap: (item) {
          Navigator.pop(context);
          _showFileActions(item);
        },
      ),
    );
  }

  void _showGlobalMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.glassLight, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _buildGlobalAction(
              icon: Icons.create_new_folder_outlined,
              label: 'New Folder',
              onTap: _handleCreateFolder,
            ),
            _buildGlobalAction(
              icon: Icons.upload_file_rounded,
              label: 'Upload File',
              onTap: _handleUpload,
            ),
            if (_copiedItem != null) ...[
              const Divider(color: AppTheme.separator, height: 1),
              _buildGlobalAction(
                icon: Icons.paste_rounded,
                label: 'Paste "${_copiedItem!.name}" Here',
                onTap: _handlePaste,
              ),
            ],
            const Divider(color: AppTheme.separator, height: 1),
            _buildGlobalAction(
              icon: _showHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              label: _showHidden ? 'Hide Hidden Files' : 'Show Hidden Files',
              onTap: () {
                setState(() {
                  _showHidden = !_showHidden;
                  _cachedAllFiles = null; 
                });
                _loadData(forceRefreshAll: true);
              },
            ),
            const Divider(color: AppTheme.separator, height: 1),
            _buildGlobalAction(
              icon: Icons.sort_rounded,
              label: 'Sort By',
              onTap: _handleSort,
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accentPrimary),
      title: Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  String _getCurrentFolderName() {
    if (_selectedCategory != null) {
      return FileCategoryHelper.getCategoryName(_selectedCategory!);
    }
    if (_currentPath == '/' || _currentPath.isEmpty) {
      return 'Storage';
    }
    return _currentPath.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _activeTab == 1 ? _items : _recentItems;
    
    return PopScope(
      canPop: _pathStack.length == 1 && _selectedCategory == null,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_selectedCategory != null) {
          _selectCategory(null);
        } else if (_pathStack.length > 1) {
          setState(() {
            _pathStack.removeLast();
            _currentPath = _pathStack.last;
          });
          _loadData();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.black)),
            CustomScrollView(
              controller: _scrollController,
              // Pre-render offscreen items for zero-lag experience
              cacheExtent: 2000,
              physics: const LenisScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: _currentPath == '/' && _selectedCategory == null ? 140 : 0,
                  toolbarHeight: 70,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.black.withOpacity(0.9),
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    centerTitle: false,
                    title: _currentPath == '/' && _selectedCategory == null
                      ? Text(
                          ApiConfig.appName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.8,
                            color: AppTheme.textPrimary,
                          ),
                        )
                      : null,
                    background: Container(color: Colors.transparent),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 26),
                      onPressed: _triggerManualReindex,
                    ),
                    IconButton(
                      key: const ValueKey('btn_search'),
                      icon: const Icon(Icons.search_rounded, size: 26),
                      onPressed: _showSearchModal,
                    ),
                    IconButton(
                      key: const ValueKey('btn_more'),
                      icon: const Icon(Icons.more_horiz_rounded, size: 26),
                      onPressed: _showGlobalMenu,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                if (_currentPath != '/' || _selectedCategory != null)
                  _buildBreadcrumbsSliver(),

                if (_currentPath == '/' && _selectedCategory == null) ...[
                  _buildStorageSwitcherSliver(),
                  _buildTabsSliver(),
                  if (_activeTab == 1) ...[
                    _buildRecentHorizontalSliver(),
                    _buildQuickAccessSliver(),
                    _buildStorageInfoSliver(),
                  ],
                ],

                _buildSectionHeaderSliver(),

                _buildMainListSliver(displayItems),

                if ((_activeTab == 0 || _selectedCategory != null) && _isListLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accentPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        floatingActionButton: _copiedItem != null ? FloatingActionButton.extended(
          onPressed: _handlePaste,
          label: Text('Paste Here (${_copiedItem?.name ?? ""})'),
          icon: const Icon(Icons.paste_rounded),
          backgroundColor: AppTheme.accentPrimary,
        ) : null,
      ),
    );
  }

  Widget _buildStorageSwitcherSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _availableStorages.map((s) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildStorageChip(
                  '${s.toUpperCase()} Storage', 
                  s, 
                  s.contains('ssd') ? Icons.flash_on_rounded : Icons.dns_rounded
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStorageChip(String label, String id, IconData icon) {
    bool isSelected = _currentStorage == id;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _currentStorage = id;
            _currentPath = '/';
            _pathStack.clear();
            _pathStack.add('/');
            _selectedCategory = null;
            _cachedAllFiles = null; // Clear cache on storage switch
          });
          _loadData(forceRefreshAll: true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentPrimary.withOpacity(0.15) : AppTheme.bgElevated.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentPrimary.withOpacity(0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.accentPrimary : AppTheme.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accentPrimary : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbsSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Text(
          _selectedCategory != null 
            ? 'Categories > ${FileCategoryHelper.getCategoryName(_selectedCategory!)}'
            : _currentPath.replaceAll('/', ' > ').replaceFirst(' > ', ''),
          style: TextStyle(
            color: AppTheme.textTertiary.withOpacity(0.5),
            fontSize: 13,
            letterSpacing: 0.1,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTabsSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.bgElevated.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(child: _buildTabButton(0, 'Recent')),
              Expanded(child: _buildTabButton(1, 'Files')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentHorizontalSliver() {
    if (_recentItems.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Recent',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _recentItems.length,
              itemBuilder: (context, index) {
                final item = _recentItems[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () => _handleOpen(item),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FileIcons.getIconForFileType(item.extension, item.isFolder),
                            color: FileIcons.getColorForFileType(item.extension, item.isFolder),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              item.name,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessSliver() {
    // Show all categories for consistent UI
    final activeCategories = FileCategory.values;

    if (activeCategories.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          SizedBox(
            height: 145,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: activeCategories.length,
              itemBuilder: (context, index) {
                final cat = activeCategories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 140,
                    child: CategoryCard(
                      category: cat,
                      fileCount: _categoryCounts[cat] ?? 0,
                      onTap: () => _selectCategory(cat),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStorageInfoSliver() {
    return SliverToBoxAdapter(
      child: _storageInfo != null 
          ? StorageInfoBar(storageInfo: _storageInfo!) 
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSectionHeaderSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Text(
          _selectedCategory != null 
             ? FileCategoryHelper.getCategoryName(_selectedCategory!)
             : (_activeTab == 0 ? 'Recently Modified' : 'All Items'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMainListSliver(List<FileItem> items) {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: AppTheme.accentPrimary)),
      );
    }

    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentPrimary))
            : const EmptyState(message: 'No files found'),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 120),
      sliver: SliverFixedExtentList(
        itemExtent: 78.0,
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return RepaintBoundary(
              child: FileListItem(
                item: item,
                storage: _currentStorage,
                isRecent: _activeTab == 0, // Mark as recent if in first tab
                onTap: () => item.isFolder ? _navigateToFolder(item) : _handleOpen(item),
                onMoreTap: () => _showFileActions(item),
              ),
            );
          },
          childCount: items.length,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
        ),
      ),
    );
  }
}

/// Custom Physics for that "Lenis" high-inertia feel
class LenisScrollPhysics extends BouncingScrollPhysics {
  const LenisScrollPhysics({super.parent});

  @override
  LenisScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LenisScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 5.0; // Easier to trigger slide

  @override
  double get maxFlingVelocity => 12000.0; // Faster max speed

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // If we're out of range, use the default spring-back logic immediately
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    
    // Within range, we use the super (BouncingScrollPhysics) simulation 
    // because it handles boundaries natively, ensuring we never overshoot.
    return super.createBallisticSimulation(position, velocity);
  }
}

extension _SliverMethods on _FileListScreenState {
  Widget _buildTabButton(int index, String label) {
    bool isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        if (_activeTab != index) {
          setState(() => _activeTab = index);
          _loadData();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AppTheme.bgCard : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// Custom Search Modal
class _SearchModal extends StatefulWidget {
  final List<FileItem> items;
  final Function(FileItem) onItemSelected;
  final Function(FileItem) onMoreTap;

  const _SearchModal({
    required this.items,
    required this.onItemSelected,
    required this.onMoreTap,
  });

  @override
  State<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<_SearchModal> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Cari file atau folder...',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                        border: InputBorder.none,
                        icon: Icon(Icons.search_rounded, color: AppTheme.accentPrimary),
                      ),
                      onChanged: (val) => setState(() => _query = val),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.accentPrimary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Results
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: EmptyState())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return FileListItem(
                        item: item,
                        storage: 'ssd', // Fallback as SearchModal doesn't have storage info passed yet
                        onTap: () => widget.onItemSelected(item),
                        onMoreTap: () => widget.onMoreTap(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Delete Confirmation Dialog
class _DeleteConfirmationDialog extends StatelessWidget {
  final FileItem item;
  final VoidCallback onConfirm;

  const _DeleteConfirmationDialog({
    required this.item,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete ${item.isFolder ? 'Folder' : 'File'}?'),
      content: Text(
        'Are you sure you want to delete "${item.name}"?\n\nThis action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.danger,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

// Rename Dialog
class _RenameDialog extends StatefulWidget {
  final FileItem item;
  final Function(String) onRename;

  const _RenameDialog({
    required this.item,
    required this.onRename,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.name);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.item.name.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'New name',
          border: OutlineInputBorder(),
        ),
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newName = _controller.text.trim();
            if (newName.isNotEmpty && newName != widget.item.name) {
              Navigator.pop(context);
              widget.onRename(newName);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

// Info Dialog
class _InfoDialog extends StatelessWidget {
  final FileItem item;

  const _InfoDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Name', value: item.name),
          _InfoRow(
            label: 'Type',
            value: item.isFolder ? 'Folder' : item.extension?.toUpperCase() ?? 'File',
          ),
          if (item.sizeBytes != null)
            _InfoRow(
              label: 'Size',
              value: '${item.sizeBytes} bytes',
            ),
          if (item.itemCount != null)
            _InfoRow(
              label: 'Items',
              value: '${item.itemCount}',
            ),
          _InfoRow(
            label: 'Modified',
            value: item.modifiedDate.toString().split('.')[0],
          ),
          _InfoRow(label: 'Path', value: item.path),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
