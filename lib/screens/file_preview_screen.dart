import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../models/file_item.dart';
import '../config/api_config.dart';
import '../data/file_repository.dart';
import '../config/theme.dart';
import '../utils/file_categories.dart';

class FilePreviewScreen extends StatefulWidget {
  final FileItem item;
  final String storage;
  final List<FileItem> galleryItems;

  const FilePreviewScreen({
    super.key,
    required this.item,
    required this.storage,
    this.galleryItems = const [],
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late FileItem _currentItem;
  late int _currentIndex;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _currentIndex = widget.galleryItems.indexOf(_currentItem);
    if (_currentIndex == -1) _currentIndex = 0;
    
    _initializePreview();
  }

  void _initializePreview() {
    final cat = FileCategoryHelper.getCategoryFromExtension(_currentItem.extension);
    if (cat == FileCategory.videos) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final url = Uri.parse(ApiConfig.preview).replace(queryParameters: {
      'storage': widget.storage,
      'path': _currentItem.path,
    }).toString();

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: {'Authorization': 'Bearer ${ApiFileRepository.token}'},
    );

    // Dispose old chewie if exists
    _chewieController?.dispose();

    try {
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.accentPrimary,
          handleColor: AppTheme.accentPrimary,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
      );
      if (mounted) setState(() => _isVideoInitialized = true);
    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = FileCategoryHelper.getCategoryFromExtension(_currentItem.extension);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          _currentItem.name,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildPreviewBody(cat),
    );
  }

  Widget _buildPreviewBody(FileCategory cat) {
    if (cat == FileCategory.photos) {
      return _buildImageGallery();
    } else if (cat == FileCategory.videos) {
      return _buildVideoPlayer();
    } else if (_currentItem.extension?.toLowerCase() == '.pdf') {
       return _buildPdfViewer();
    } else {
      return _buildGenericPreview();
    }
  }

  Widget _buildImageGallery() {
    final items = widget.galleryItems.isEmpty ? [_currentItem] : widget.galleryItems;
    final startIndex = widget.galleryItems.indexOf(_currentItem);
    
    return PhotoViewGallery.builder(
      itemCount: items.length,
      builder: (context, index) {
        final item = items[index];
        final url = Uri.parse(ApiConfig.preview).replace(queryParameters: {
          'storage': widget.storage,
          'path': item.path,
        }).toString();

        return PhotoViewGalleryPageOptions(
          imageProvider: NetworkImage(
            url,
            headers: {'Authorization': 'Bearer ${ApiFileRepository.token}'},
          ),
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: item.path),
        );
      },
      pageController: PageController(initialPage: startIndex != -1 ? startIndex : 0),
      loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()),
      onPageChanged: (index) {
        if (mounted) setState(() => _currentItem = items[index]);
      },
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized || _chewieController == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentPrimary));
    }
    return Center(
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildPdfViewer() {
    final url = Uri.parse(ApiConfig.preview).replace(queryParameters: {
      'storage': widget.storage,
      'path': _currentItem.path,
    }).toString();

    return SfPdfViewer.network(
      url,
      headers: {'Authorization': 'Bearer ${ApiFileRepository.token}'},
    );
  }

  Widget _buildGenericPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FileCategoryHelper.getCategoryIcon(FileCategoryHelper.getCategoryFromExtension(_currentItem.extension)),
            size: 100,
            color: AppTheme.accentPrimary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            _currentItem.name,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Preview not available for this file type.',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
               // Fallback to open_filex logic in parent or direct download
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open with External App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
