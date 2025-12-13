import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart'; // Pour la molette souris
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart'; // Pour sauvegarder le fichier
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
  IptvSource? currentSource; // La source active
  
  // --- ÉTAT ---
  bool isLoading = false;
  bool showVolumeIndicator = false; // Pour afficher le volume quand on scroll
  double currentVolume = 100.0;
  Timer? _volumeTimer; // Pour cacher l'indicateur après 2 sec

  int _selectedIndex = 0; // 0 = TV, 1 = Paramètres
  late TabController _settingsTabController;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _settingsTabController = TabController(length: 2, vsync: this);
    
    // Config Player
    player = Player();
    controller = VideoController(player);
    // On charge le volume initial
    currentVolume = player.state.volume;

    _loadSources();
  }

  Future<void> _loadSources() async {
    final s = await StorageService.getSources();
    setState(() => sources = s);
    if (s.isNotEmpty) {
      _loadChannelsFromSource(s.first);
    }
  }

  Future<void> _loadChannelsFromSource(IptvSource source) async {
    setState(() {
      isLoading = true;
      currentSource = source; // On mémorise la source active
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
        _snack("Erreur chargement: $e", Colors.red);
      }
    }
  }

  Future<void> _playChannel(Channel channel) async {
    setState(() => currentChannel = channel);
    await player.open(Media(channel.url));
  }

  // --- NOUVEAU : GESTION VOLUME MOLETTE ---
  void _onScrollVolume(PointerScrollEvent event) {
    // dy < 0 = Scroll vers le haut (Monter son)
    // dy > 0 = Scroll vers le bas (Baisser son)
    double delta = event.scrollDelta.dy < 0 ? 5.0 : -5.0;
    
    double newVol = (player.state.volume + delta).clamp(0.0, 100.0);
    player.setVolume(newVol);

    setState(() {
      currentVolume = newVol;
      showVolumeIndicator = true;
    });

    // Cacher l'indicateur après 1.5 secondes
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => showVolumeIndicator = false);
    });
  }

  // --- NOUVEAU : EXPORT M3U ---
  Future<void> _exportCurrentPlaylist() async {
    if (currentChannelList.isEmpty) {
      _snack("Aucune chaîne à exporter. Chargez une playlist d'abord.", Colors.orange);
      return;
    }

    // 1. Demander où sauvegarder
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporter la playlist en M3U',
      fileName: '${currentSource?.name ?? "playlist"}_export.m3u',
      allowedExtensions: ['m3u'],
      type: FileType.custom,
    );

    if (outputFile != null) {
      // 2. Générer le contenu M3U
      StringBuffer buffer = StringBuffer();
      buffer.writeln("#EXTM3U");
      
      for (var ch in currentChannelList) {
        // Format standard: #EXTINF:-1 tvg-logo="..." group-title="...",Nom
        buffer.write('#EXTINF:-1');
        if (ch.logoUrl != null) buffer.write(' tvg-logo="${ch.logoUrl}"');
        if (ch.group != null) buffer.write(' group-title="${ch.group}"');
        buffer.writeln(',${ch.name}');
        buffer.writeln(ch.url);
      }

      // 3. Écrire le fichier
      try {
        final file = File(outputFile);
        // Ajout extension si manquante
        if (!outputFile.endsWith('.m3u')) {
           // On pourrait renommer, mais saveFile gère souvent ça.
        }
        await file.writeAsString(buffer.toString());
        _snack("✅ Export réussi : $outputFile", Colors.green);
      } catch (e) {
        _snack("Erreur export: $e", Colors.red);
      }
    }
  }

  void _nextChannel() {
    if (currentChannel == null || filteredChannels.isEmpty) return;
    int index = filteredChannels.indexOf(currentChannel!);
    if (index < filteredChannels.length - 1) {
      _playChannel(filteredChannels[index + 1]);
    }
  }

  void _prevChannel() {
    if (currentChannel == null || filteredChannels.isEmpty) return;
    int index = filteredChannels.indexOf(currentChannel!);
    if (index > 0) {
      _playChannel(filteredChannels[index - 1]);
    }
  }

  void _showAudioTracks() {
    final tracks = player.state.tracks.audio;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      builder: (ctx) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: tracks.length,
          itemBuilder: (ctx, i) {
            final track = tracks[i];
            return ListTile(
              title: Text(track.title ?? track.language ?? "Piste ${i + 1}", 
                style: const TextStyle(color: Colors.white)),
              subtitle: Text(track.id, style: const TextStyle(color: Colors.grey)),
              onTap: () {
                player.setAudioTrack(track);
                Navigator.pop(context);
                _snack("Audio changé: ${track.language}", Colors.blue);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addSource(String name, String url, SourceType type, {String u = "", String p = ""}) async {
    final newSource = IptvSource(name: name, type: type, url: url, username: u, password: p);
    await StorageService.addSource(newSource);
    await _loadSources();
    _snack("Playlist ajoutée !", Colors.green);
    setState(() => _selectedIndex = 0); 
  }

  void _filterChannels(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredChannels = currentChannelList;
      } else {
        filteredChannels = currentChannelList
            .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2),
    ));
  }

  @override
  void dispose() {
    player.dispose();
    _settingsTabController.dispose();
    _volumeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 1. RAIL DE NAVIGATION
          NavigationRail(
            backgroundColor: const Color(0xFF1A1A1A),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.tv, color: Colors.blue, size: 30),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.live_tv),
                label: Text('Chaînes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Paramètres'),
              ),
            ],
          ),

          // 2. PANNEAU LATÉRAL
          SizedBox(
            width: 320,
            child: Container(
              color: const Color(0xFF252525),
              child: _selectedIndex == 0 
                ? _buildChannelPanel() 
                : _buildSettingsPanel(),
            ),
          ),

          // 3. LECTEUR VIDÉO AVEC ÉCOUTEUR MOLETTE
          Expanded(
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _onScrollVolume(event);
                }
              },
              child: Stack(
                children: [
                  // La Vidéo
                  Container(
                    color: Colors.black,
                    child: Center(child: Video(controller: controller)),
                  ),

                  // Overlay Contrôles (Suivant / Précédent / Audio)
                  _buildVideoOverlay(),
                  
                  // Indicateur de Volume (Gros au milieu quand on scroll)
                  if (showVolumeIndicator)
                    Center(
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
                              currentVolume == 0 ? Icons.volume_off : Icons.volume_up, 
                              color: Colors.white, size: 40
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "${currentVolume.toInt()}%",
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 100,
                              child: LinearProgressIndicator(
                                value: currentVolume / 100,
                                color: Colors.blue,
                                backgroundColor: Colors.white24,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DU PANNEAU GAUCHE ---

  Widget _buildChannelPanel() {
    return Column(
      children: [
        // Sélecteur de Source
        Container(
          padding: const EdgeInsets.all(10),
          color: const Color(0xFF303030),
          child: DropdownButtonFormField<IptvSource>(
            decoration: const InputDecoration(labelText: "Playlist active", border: OutlineInputBorder()),
            value: sources.contains(currentSource) ? currentSource : null,
            isExpanded: true,
            items: sources.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
            onChanged: (s) {
              if (s != null) _loadChannelsFromSource(s);
            },
          ),
        ),
        
        // Recherche
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _filterChannels,
            decoration: const InputDecoration(
              hintText: "Rechercher...",
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Color(0xFF333333),
            ),
          ),
        ),

        // Liste des chaînes
        Expanded(
          child: isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : ListView.builder(
                itemCount: filteredChannels.length,
                itemBuilder: (ctx, i) {
                  final ch = filteredChannels[i];
                  final isSelected = currentChannel?.id == ch.id;
                  return Container(
                    color: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : null,
                    child: ListTile(
                      dense: true,
                      leading: ch.logoUrl != null 
                        ? Image.network(
                            ch.logoUrl!, 
                            width: 30, 
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.tv)
                          ) 
                        : const Icon(Icons.tv),
                      title: Text(ch.name, style: TextStyle(
                        color: isSelected ? Colors.blueAccent : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      )),
                      onTap: () => _playChannel(ch),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          child: const Text("Ajouter une Source", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        
        // --- BOUTON D'EXPORT ---
        if (currentChannelList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.download),
              label: const Text("Exporter la playlist active (.m3u)"),
              onPressed: _exportCurrentPlaylist,
            ),
          ),
        
        const Divider(),

        TabBar(
          controller: _settingsTabController,
          tabs: const [
            Tab(text: "Lien M3U"),
            Tab(text: "Xtream Codes"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _settingsTabController,
            children: [
              // Onglet M3U
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom de la playlist")),
                    const SizedBox(height: 10),
                    TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "URL M3U")),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Ajouter M3U"),
                      onPressed: () => _addSource(nameCtrl.text, urlCtrl.text, SourceType.m3u),
                    )
                  ],
                ),
              ),
              // Onglet Xtream
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom")),
                    const SizedBox(height: 10),
                    TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "URL Serveur (http://...)")),
                    const SizedBox(height: 10),
                    TextField(controller: userCtrl, decoration: const InputDecoration(labelText: "Utilisateur")),
                    const SizedBox(height: 10),
                    TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Mot de passe"), obscureText: true),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.dns),
                      label: const Text("Ajouter Xtream"),
                      onPressed: () => _addSource(nameCtrl.text, urlCtrl.text, SourceType.xtream, u: userCtrl.text, p: passCtrl.text),
                    )
                  ],
                ),
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
        // Bouton Précédent
        Positioned(
          left: 0, top: 100, bottom: 100, width: 100,
          child: InkWell(
            onTap: _prevChannel,
            hoverColor: Colors.black12,
            child: const Center(child: Icon(Icons.arrow_back_ios, size: 40, color: Colors.white24)),
          ),
        ),
        
        // Bouton Suivant
        Positioned(
          right: 0, top: 100, bottom: 100, width: 100,
          child: InkWell(
            onTap: _nextChannel,
            hoverColor: Colors.black12,
            child: const Center(child: Icon(Icons.arrow_forward_ios, size: 40, color: Colors.white24)),
          ),
        ),

        // Barre d'outils haut droite
        Positioned(
          top: 20, right: 20,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
                child: IconButton(
                  icon: const Icon(Icons.audiotrack, color: Colors.white),
                  tooltip: "Changer la langue",
                  onPressed: _showAudioTracks,
                ),
              ),
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
}