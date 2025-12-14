// ==========================================
// lib/widgets/volume_indicator.dart
// ==========================================
import 'package:flutter/material.dart';

class VolumeIndicator extends StatelessWidget {
  final double volume;

  const VolumeIndicator({super.key, required this.volume});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              volume == 0 ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 40,
            ),
            Text(
              "${volume.toInt()}%",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}