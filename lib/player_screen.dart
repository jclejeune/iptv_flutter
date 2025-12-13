import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart'; // Moteur Vidéo
import 'package:media_kit_video/media_kit_video.dart'; // Affichage Vidéo
import 'package:file_picker/file_picker.dart';
import 'models.dart';
import 'services.dart';

class IptvDashboard extends StatefulWidget {
  const IptvDashboard({super.key});

  @override
  State<IptvDashboard> createState() => _IptvDashboardState();
}

class _IptvDashboardState extends State<IptvDashboard> with TickerProviderStateMixin {
  // --- MOTEUR VIDÉO ---
  late final Player player;
  late final VideoController controller;

  // --- DONNÉES ---
  List<IptvSource> sources = [];
  List<Channel> currentChannelList = [];
  List<Channel> filteredChannels = [];
  Channel? currentChannel;
  IptvSource? currentSource;
  
  // --- ÉTAT ---
  bool isLoading = false;
  bool showVolumeIndicator = false;
  double currentVolume = 100.0;
  Timer? _volumeTimer;
  Timer? _overlayTimer; // Pour cacher l'overlay auto

  // Gestion UI / Navigation
  int _selectedIndex = 0; 
  late TabController _settingsTabController;
  final TextEditingController _searchCtrl = TextEditingController();

  // --- NOUVEAU : GESTION PLEIN ÉCRAN & MENU FLOTTANT ---
  bool _isFullScreenMode = false; // Si vrai, on cache la barre fixe
  bool _showFloatingMenu = false; // Si vrai, on montre le menu transparent

  @override
  void initState() {
    super.initState();
    _settingsTabController = TabController(length: 2, vsync: this);
    
    player = Player();
    controller = VideoController(player);
    currentVolume = player.state.volume;

    _loadSources();
  }

  Future<void> _loadSources() async {
    final s = await StorageService.getSources();
    setState(() => sources = s);
    if (s.isNotEmpty) _loadChannelsFromSource(s.first);
  }

  Future<void> _loadChannelsFromSource(IptvSource source) async {
    setState(() {
      isLoading = true;
      currentSource = source;
    });
    try {
      final list = await ApiService.getChannelsFromSource(source);
      if (mounted) {
        setState(() {
          currentChannelList = list;
          filteredChannels = list;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _snack("Erreur: $e", Colors.red);
      }
    }
  }

  Future<void> _playChannel(Channel channel) async {
    setState(() => currentChannel = channel);
    await player.open(Media(channel.url));
  }

  // --- ACTIONS ---

  void _toggleFullScreen() {
    setState(() {
      _isFullScreenMode = !_isFullScreenMode;
      // On cache le menu flottant si on quitte le plein écran
      if (!_isFullScreenMode) _showFloatingMenu = false;
    });
  }

  void _onHoverScreen(PointerHoverEvent event) {
    if (!_isFullScreenMode) return;

    // Si la souris est tout à gauche (0-50 pixels), on montre le menu
    if (event.position.dx < 50) {
      if (!_showFloatingMenu) setState(() => _showFloatingMenu = true);
    } 
    // Si la souris s'éloigne trop (plus de 350 pixels), on le cache
    else if (event.position.dx > 350) {
      if (_showFloatingMenu) setState(() => _showFloatingMenu = false);
    }
  }

  void _onScrollVolume(PointerScrollEvent event) {
    double delta = event.scrollDelta.dy < 0 ? 5.0 : -5.0;
    double newVol = (player.state.volume + delta).clamp(0.0, 100.0);
    player.setVolume(newVol);

    setState(() {
      currentVolume = newVol;
      showVolumeIndicator = true;
    });

    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => showVolumeIndicator = false);
    });
  }

  Future<void> _exportCurrentPlaylist() async {
    if (currentChannelList.isEmpty) return;
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporter M3U',
      fileName: '${currentSource?.name ?? "playlist"}.m3u',
      allowedExtensions: ['m3u'],
      type: FileType.custom,
    );

    if (outputFile != null) {
      StringBuffer buffer = StringBuffer();
      buffer.writeln("#EXTM3U");
      for (var ch in currentChannelList) {
        buffer.write('#EXTINF:-1');
        if (ch.logoUrl != null) buffer.write(' tvg-logo="${ch.logoUrl}"');
        if (ch.group != null) buffer.write(' group-title="${ch.group}"');
        buffer.writeln(',${ch.name}');
        buffer.writeln(ch.url);
      }
      File(outputFile).writeAsString(buffer.toString());
      _snack("Export réussi !", Colors.green);
    }
  }

  // Zapping
  void _nextChannel() => _zap(1);
  void _prevChannel() => _zap(-1);
  void _zap(int dir) {
    if (currentChannel == null || filteredChannels.isEmpty) return;
    int index = filteredChannels.indexOf(currentChannel!);
    int newIndex = index + dir;
    if (newIndex >= 0 && newIndex < filteredChannels.length) {
      _playChannel(filteredChannels[newIndex]);
    }
  }

  void _showAudioTracks() {
    final tracks = player.state.tracks.audio;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: tracks.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(tracks[i].title ?? tracks[i].language ?? "Piste ${i+1}", style: const TextStyle(color: Colors.white)),
          onTap: () {
            player.setAudioTrack(tracks[i]);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _addSource(String name, String url, SourceType type, {String u = "", String p = ""}) async {
    final newSource = IptvSource(name: name, type: type, url: url, username: u, password: p);
    await StorageService.addSource(newSource);
    await _loadSources();
    setState(() => _selectedIndex = 0); 
  }

  void _filterChannels(String query) {
    setState(() {
      filteredChannels = query.isEmpty 
          ? currentChannelList 
          : currentChannelList.where((c) => c.name.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  void dispose() {
    player.dispose();
    _settingsTabController.dispose();
    _volumeTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  // --- CONSTRUCTION UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // MouseRegion globale pour détecter les mouvements (Menu Flottant)
      body: MouseRegion(
        onHover: _onHoverScreen,
        child: Stack(
          children: [
            // COUCHE 1 : LE CONTENU PRINCIPAL
            Row(
              children: [
                // 1. Barre de navigation & Panneau Latéral (Cachés en mode Plein Écran)
                if (!_isFullScreenMode) ...[
                  NavigationRail(
                    backgroundColor: const Color(0xFF1A1A1A),
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
                    labelType: NavigationRailLabelType.all,
                    leading: const Icon(Icons.tv, color: Colors.blue, size: 30),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.live_tv), label: Text('Chaînes')),
                      NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Paramètres')),
                    ],
                  ),
                  SizedBox(
                    width: 320,
                    child: Container(
                      color: const Color(0xFF252525),
                      child: _selectedIndex == 0 ? _buildChannelListUI(isTransparent: false) : _buildSettingsPanel(),
                    ),
                  ),
                ],

                // 2. Le Lecteur Vidéo (Prend toute la place restante)
                Expanded(
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) _onScrollVolume(event);
                    },
                    child: Stack(
                      children: [
                        Container(color: Colors.black, child: Center(child: Video(controller: controller))),
                        _buildVideoOverlay(),
                        if (showVolumeIndicator) _buildVolumeIndicator(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // COUCHE 2 : LE MENU FLOTTANT (Visible uniquement en plein écran + souris à gauche)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              left: _showFloatingMenu ? 0 : -320, // Glisse depuis la gauche
              top: 0,
              bottom: 0,
              width: 320,
              child: Container(
                // Fond semi-transparent pour effet "TV"
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85), 
                  boxShadow: [const BoxShadow(color: Colors.black, blurRadius: 20)],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Text("Liste des chaînes", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: _buildChannelListUI(isTransparent: true)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  // Liste des chaînes réutilisable (pour le panneau fixe ET le menu flottant)
  Widget _buildChannelListUI({required bool isTransparent}) {
    Color itemColor = isTransparent ? Colors.transparent : Colors.transparent;
    //Color hoverColor = isTransparent ? Colors.white10 : Colors.blueAccent.withValues(alpha: 0.1);

    return Column(
      children: [
        if (!isTransparent) // En mode fixe, on montre le selecteur de source
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF303030),
            child: DropdownButtonFormField<IptvSource>(
              decoration: const InputDecoration(labelText: "Playlist", border: OutlineInputBorder()),
              value: sources.contains(currentSource) ? currentSource : null,
              isExpanded: true,
              items: sources.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
              onChanged: (s) { if (s != null) _loadChannelsFromSource(s); },
            ),
          ),
        
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _filterChannels,
            decoration: InputDecoration(
              hintText: "Rechercher...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isTransparent ? Colors.white10 : const Color(0xFF333333),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),

        Expanded(
          child: isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : ListView.builder(
                itemCount: filteredChannels.length,
                itemBuilder: (ctx, i) {
                  final ch = filteredChannels[i];
                  final isSelected = currentChannel?.id == ch.id;
                  return Container(
                    color: isSelected ? Colors.blueAccent.withValues(alpha: isTransparent ? 0.4 : 0.2) : itemColor,
                    child: ListTile(
                      dense: true,
                      leading: ch.logoUrl != null 
                        ? Image.network(ch.logoUrl!, width: 30, errorBuilder: (ctx,e,s) => const Icon(Icons.tv)) 
                        : const Icon(Icons.tv),
                      title: Text(ch.name, style: TextStyle(
                        color: isSelected ? Colors.blueAccent : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      )),
                      onTap: () {
                        _playChannel(ch);
                        // Si on est en menu flottant, on peut le fermer après clic si on veut (optionnel)
                        // setState(() => _showFloatingMenu = false); 
                      },
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    // (Même code que précédemment pour les réglages)
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    return Column(
      children: [
        Container(padding: const EdgeInsets.all(15), child: const Text("Paramètres", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        if (currentChannelList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.download),
              label: const Text("Exporter Playlist (.m3u)"),
              onPressed: _exportCurrentPlaylist,
            ),
          ),
        const Divider(),
        TabBar(
          controller: _settingsTabController,
          tabs: const [Tab(text: "Lien M3U"), Tab(text: "Xtream")],
        ),
        Expanded(
          child: TabBarView(
            controller: _settingsTabController,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom")),
                  const SizedBox(height: 10),
                  TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "URL")),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: () => _addSource(nameCtrl.text, urlCtrl.text, SourceType.m3u), child: const Text("Ajouter")),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom")),
                  TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "URL")),
                  TextField(controller: userCtrl, decoration: const InputDecoration(labelText: "User")),
                  TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Pass")),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: () => _addSource(nameCtrl.text, urlCtrl.text, SourceType.xtream, u: userCtrl.text, p: passCtrl.text), child: const Text("Ajouter")),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoOverlay() {
    return Stack(
      children: [
        // Zapping zones invisibles
        Positioned(left: 0, top: 100, bottom: 100, width: 80, child: InkWell(onTap: _prevChannel, child: const Center(child: Icon(Icons.arrow_back_ios, color: Colors.white12)))),
        Positioned(right: 0, top: 100, bottom: 100, width: 80, child: InkWell(onTap: _nextChannel, child: const Center(child: Icon(Icons.arrow_forward_ios, color: Colors.white12)))),

        // Barre d'outils haut droite
        Positioned(
          top: 20, right: 20,
          child: Row(
            children: [
              // NOUVEAU : Bouton Plein Écran
              IconButton(
                icon: Icon(_isFullScreenMode ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 30),
                tooltip: _isFullScreenMode ? "Afficher le menu" : "Plein écran",
                onPressed: _toggleFullScreen,
              ),
              const SizedBox(width: 10),
              IconButton(icon: const Icon(Icons.audiotrack, color: Colors.white), onPressed: _showAudioTracks),
              const SizedBox(width: 10),
              if (currentChannel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                  child: Text(currentChannel!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildVolumeIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(currentVolume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 40),
            Text("${currentVolume.toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}