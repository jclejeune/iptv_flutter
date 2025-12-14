// ==========================================
// lib/widgets/settings_panel.dart
// ==========================================
import 'package:flutter/material.dart';
import '../models.dart';

class SettingsPanel extends StatefulWidget {
  final TabController tabController;
  final bool hasChannels;
  final VoidCallback onExportPlaylist;
  final Function(String, String, SourceType, String, String) onAddSource;

  const SettingsPanel({
    super.key,
    required this.tabController,
    required this.hasChannels,
    required this.onExportPlaylist,
    required this.onAddSource,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final _m3uNameCtrl = TextEditingController();
  final _m3uUrlCtrl = TextEditingController();
  final _xtreamNameCtrl = TextEditingController();
  final _xtreamUrlCtrl = TextEditingController();
  final _xtreamUserCtrl = TextEditingController();
  final _xtreamPassCtrl = TextEditingController();

  @override
  void dispose() {
    _m3uNameCtrl.dispose();
    _m3uUrlCtrl.dispose();
    _xtreamNameCtrl.dispose();
    _xtreamUrlCtrl.dispose();
    _xtreamUserCtrl.dispose();
    _xtreamPassCtrl.dispose();
    super.dispose();
  }

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
            Tab(text: "Lien M3U"),
            Tab(text: "Xtream"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: widget.tabController,
            children: [
              _buildM3uForm(),
              _buildXtreamForm(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildM3uForm() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(
            controller: _m3uNameCtrl,
            decoration: const InputDecoration(labelText: "Nom"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _m3uUrlCtrl,
            decoration: const InputDecoration(labelText: "URL"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_m3uNameCtrl.text.isNotEmpty && _m3uUrlCtrl.text.isNotEmpty) {
                widget.onAddSource(
                  _m3uNameCtrl.text,
                  _m3uUrlCtrl.text,
                  SourceType.m3u,
                  '',
                  '',
                );
                _m3uNameCtrl.clear();
                _m3uUrlCtrl.clear();
              }
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  Widget _buildXtreamForm() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(
            controller: _xtreamNameCtrl,
            decoration: const InputDecoration(labelText: "Nom"),
          ),
          TextField(
            controller: _xtreamUrlCtrl,
            decoration: const InputDecoration(labelText: "URL"),
          ),
          TextField(
            controller: _xtreamUserCtrl,
            decoration: const InputDecoration(labelText: "User"),
          ),
          TextField(
            controller: _xtreamPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Pass"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_xtreamNameCtrl.text.isNotEmpty && 
                  _xtreamUrlCtrl.text.isNotEmpty &&
                  _xtreamUserCtrl.text.isNotEmpty &&
                  _xtreamPassCtrl.text.isNotEmpty) {
                widget.onAddSource(
                  _xtreamNameCtrl.text,
                  _xtreamUrlCtrl.text,
                  SourceType.xtream,
                  _xtreamUserCtrl.text,
                  _xtreamPassCtrl.text,
                );
                _xtreamNameCtrl.clear();
                _xtreamUrlCtrl.clear();
                _xtreamUserCtrl.clear();
                _xtreamPassCtrl.clear();
              }
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }
}