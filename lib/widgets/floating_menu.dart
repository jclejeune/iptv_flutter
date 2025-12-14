import 'package:flutter/material.dart';
import '../models.dart';
import 'channel_list.dart';

class FloatingMenu extends StatelessWidget {
  final bool isVisible;
  final List<Channel> channels;
  final Channel? selectedChannel;
  final Function(Channel) onChannelTap;
  final Function(String) onSearch;

  const FloatingMenu({
    super.key,
    required this.isVisible,
    required this.channels,
    this.selectedChannel,
    required this.onChannelTap,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      left: isVisible ? 0 : -320,
      top: 0,
      bottom: 0,
      width: 320,
      child: Container(
        decoration: BoxDecoration(
          // ✅ Utilise withValues au lieu de withOpacity
          color: Colors.black.withValues(alpha: 0.85),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 20)],
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(15.0),
                child: Text(
                  "Liste des chaînes",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ChannelList(
                  channels: channels,
                  selectedChannel: selectedChannel,
                  onChannelTap: onChannelTap,
                  onSearch: onSearch,
                  isTransparent: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}