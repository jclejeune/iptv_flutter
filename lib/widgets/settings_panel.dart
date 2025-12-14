// ==========================================
// 3. MODIFICATION SETTINGS_PANEL
// lib/widgets/settings_panel.dart (REMPLACER COMPLÈTEMENT)
// ==========================================

import 'package:flutter/material.dart';
import '../models.dart';
import 'playlist_manager.dart';

class SettingsPanel extends StatefulWidget {
  final TabController tabController;
  final bool hasChannels;
  final VoidCallback onExportPlaylist;
  final List<IptvSource> sources;
  final Function() onSourcesChanged;

  const SettingsPanel({
    super.key,
    required this.tabController,
    required this.hasChannels,
    required this.onExportPlaylist,
    required this.sources,
    required this.onSourcesChanged,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(15),
          child: Text(
            "Paramètres",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        if (widget.hasChannels)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.download),
              label: const Text("Exporter Playlist (.m3u)"),
              onPressed: widget.onExportPlaylist,
            ),
          ),
        const Divider(),
        TabBar(
          controller: widget.tabController,
          tabs: const [
            Tab(text: "Mes Playlists", icon: Icon(Icons.list)),
            Tab(text: "À Propos", icon: Icon(Icons.info)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: widget.tabController,
            children: [
              PlaylistManager(
                sources: widget.sources,
                onSourcesChanged: widget.onSourcesChanged,
              ),
              _buildAboutTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    return const Padding(
      padding: EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IPTV Master Pro',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text('Version 2.0.0', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 20),
          Text(
            'Lecteur IPTV complet pour Windows',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          Text('Fonctionnalités:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text('• Support M3U et Xtream Codes'),
          Text('• Lecture HD/4K'),
          Text('• Gestion multi-playlists'),
          Text('• Export M3U'),
          Text('• Mode plein écran'),
          Text('• Zapping rapide'),
        ],
      ),
    );
  }
}