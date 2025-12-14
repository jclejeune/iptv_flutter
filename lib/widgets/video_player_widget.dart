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
          // Inversion du scroll pour un feeling plus naturel (Haut = Monter le volume)
          onVolumeChange(event.scrollDelta.dy < 0 ? 5.0 : -5.0);
        }
      },
      child: Stack(
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: Video(
                controller: controller,
                controls: NoVideoControls, // On utilise nos propres contrôles
              ),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Stack(
      children: [
        // Zone invisible gauche pour zapper en arrière
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
        // Zone invisible droite pour zapper en avant
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
        // Barre supérieure
        Positioned(
          top: 20,
          right: 20,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                  size: 30,
                ),
                tooltip: isFullScreen ? "Quitter Plein écran" : "Plein écran",
                onPressed: onToggleFullScreen,
              ),
              IconButton(
                icon: const Icon(Icons.audiotrack, color: Colors.white),
                tooltip: "Pistes Audio",
                onPressed: onShowAudioTracks,
              ),
              if (currentChannel != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    currentChannel!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}