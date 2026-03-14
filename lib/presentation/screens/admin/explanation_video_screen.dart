import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ExplanationVideoScreen extends StatefulWidget {
  final String videoUrl;

  const ExplanationVideoScreen({super.key, required this.videoUrl});

  @override
  State<ExplanationVideoScreen> createState() => _ExplanationVideoScreenState();
}

class _ExplanationVideoScreenState extends State<ExplanationVideoScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    print('🎬 Initializing Video Player...');
    print('🔗 URL: ${widget.videoUrl}');
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return _buildStaticErrorUI(errorMessage);
        },
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: AppColors.primary.withOpacity(0.5),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: AppColors.primary.withOpacity(0.5),
        ),
      );

      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'شرح المنصة',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _isError
              ? _buildErrorContent()
              : _chewieController != null &&
                      _videoPlayerController != null &&
                      _videoPlayerController!.value.isInitialized
                  ? Chewie(controller: _chewieController!)
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('جاري تحميل الفيديو...',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildStaticErrorUI(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              'هذا الهاتف لا يدعم تشغيل هذه الجودة العالية داخلياً',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('تشغيل في المتصفح الخارجي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 48),
        const SizedBox(height: 16),
        Text(
          'حدث خطأ أثناء تحميل الفيديو',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _openInBrowser,
          icon: const Icon(Icons.open_in_browser_rounded),
          label: const Text('فتح في المتصفح'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() => _isError = false);
            _initializePlayer();
          },
          child: const Text('إعادة المحاولة داخل التطبيق',
              style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.videoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
