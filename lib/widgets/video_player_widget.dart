// ==========================================
// CORRECTION VIDÉO INTÉGRÉE
// lib/widgets/video_player_widget.dart
// ==========================================

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models.dart';

class VideoPlayerWidget extends StatelessWidget {
  final VideoController controller;
  final Channel? currentChannel;
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;
  final VoidCallback onShowAudioTracks;
  final VoidCallback onPrevChannel;
  final VoidCallback onNextChannel;
  final Function(double) onVolumeChange;

  const VideoPlayerWidget({
    super.key,
    required this.controller,
    this.currentChannel,
    required this.isFullScreen,
    required this.onToggleFullScreen,
    required this.onShowAudioTracks,
    required this.onPrevChannel,
    required this.onNextChannel,
    required this.onVolumeChange,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          onVolumeChange(event.scrollDelta.dy < 0 ? 5.0 : -5.0);
        }
      },
      child: Container(
        color: Colors.black,
        // ✅ CORRECTION : ClipRect pour forcer le confinement
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ✅ CORRECTION : Video avec aspectRatio
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Video(
                    controller: controller,
                    controls: NoVideoControls,
                  ),
                ),
              ),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 100,
          bottom: 100,
          width: 80,
          child: InkWell(
            onTap: onPrevChannel,
            hoverColor: Colors.white10,
            child: const Center(
              child: Icon(Icons.arrow_back_ios, color: Colors.white24, size: 40),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 100,
          bottom: 100,
          width: 80,
          child: InkWell(
            onTap: onNextChannel,
            hoverColor: Colors.white10,
            child: const Center(
              child: Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 40),
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: isFullScreen ? "Quitter" : "Plein écran",
                  onPressed: onToggleFullScreen,
                ),
                IconButton(
                  icon: const Icon(Icons.audiotrack, color: Colors.white, size: 28),
                  tooltip: "Pistes Audio",
                  onPressed: onShowAudioTracks,
                ),
                if (currentChannel != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      currentChannel!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}