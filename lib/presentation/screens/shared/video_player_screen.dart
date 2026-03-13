import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:edu_platform_app/core/constants/app_colors.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    // Allow all orientations for video playback
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide system UI (status bar and navigation bar)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl) ?? '';
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
        isLive: false,
        forceHD: false,
        hideControls: false, // Internal Flutter controls handle visibility
        controlsVisibleAtStart: true,
        loop: true,
        disableDragSeek: false,
        hideThumbnail: true,
        useHybridComposition: true,
      ),
    )..addListener(_listener);
  }

  void _listener() {
    // Handle fullscreen mode changes
    if (mounted) {
      if (_controller.value.isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      }
    }
  }

  @override
  void dispose() {
    if (_controller.value.isFullScreen) {
      _controller.toggleFullScreenMode();
    }
    _controller.removeListener(_listener);
    _controller.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primary,
        // Remove custom controls to use YouTube's native controls which include quality settings
        onReady: () {
          print('YouTube Player is ready');
        },
      ),
      builder: (context, player) {
        return WillPopScope(
          onWillPop: () async {
            if (_controller.value.isFullScreen) {
              _controller.toggleFullScreenMode();
              return false;
            }
            return true;
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            appBar: _controller.value.isFullScreen
                ? null // Hide app bar in fullscreen
                : AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _showSettingsBottomSheet,
                        ),
                      ),
                    ],
                  ),
            body: Center(child: player),
          ),
        );
      },
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'إعدادات الفيديو',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.high_quality_rounded,
                color: Colors.white,
              ),
              title: const Text(
                'جودة الفيديو',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
              onTap: () {
                Navigator.pop(context);
                _showVideoQualityDialog();
              },
            ),
            const Divider(color: Colors.grey, height: 1),
            ListTile(
              leading: const Icon(Icons.speed_rounded, color: Colors.white),
              title: const Text(
                'سرعة التشغيل',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
              onTap: () {
                Navigator.pop(context);
                _showPlaybackSpeedDialog();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showVideoQualityDialog() {
    final qualities = [
      {'label': 'تلقائي (Auto)', 'value': 'auto', 'icon': Icons.auto_awesome},
      {'label': '144p', 'value': 'tiny', 'icon': Icons.sd},
      {'label': '240p', 'value': 'small', 'icon': Icons.sd},
      {'label': '360p', 'value': 'medium', 'icon': Icons.sd},
      {'label': '480p', 'value': 'large', 'icon': Icons.hd},
      {'label': '720p (HD)', 'value': 'hd720', 'icon': Icons.hd},
      {'label': '1080p (Full HD)', 'value': 'hd1080', 'icon': Icons.hd},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'جودة الفيديو',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'اختر جودة الفيديو المفضلة',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            ...qualities.map((quality) {
              return ListTile(
                leading: Icon(
                  quality['icon'] as IconData,
                  color: Colors.white70,
                ),
                title: Text(
                  quality['label'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم اختيار جودة ${quality['label'] as String}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  Navigator.pop(context);
                },
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPlaybackSpeedDialog() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              'سرعة التشغيل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: speeds.length,
                itemBuilder: (context, index) {
                  final speed = speeds[index];
                  return ListTile(
                    title: Text(
                      '${speed}x',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: _controller.value.playbackRate == speed
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      _controller.setPlaybackRate(speed);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
