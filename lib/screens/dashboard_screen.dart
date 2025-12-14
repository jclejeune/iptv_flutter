// ==========================================
// lib/screens/dashboard_screen.dart
// ==========================================

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/channel_list.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/volume_indicator.dart';
import '../widgets/floating_menu.dart';
import '../widgets/settings_panel.dart';

class IptvDashboard extends StatefulWidget {
  const IptvDashboard({super.key});

  @override
  State<IptvDashboard> createState() => _IptvDashboardState();
}

class _IptvDashboardState extends State<IptvDashboard>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final VideoController _controller;

  final List<IptvSource> _sources = [];
  List<Channel> _allChannels = [];
  List<Channel> _filteredChannels = [];
  Channel? _currentChannel;
  IptvSource? _currentSource;

  bool _isLoading = false;
  bool _isFullScreen = false;
  bool _showFloatingMenu = false;
  bool _showVolume = false;
  double _volume = 100.0;
  int _selectedTab = 0;
  String? _lastError;

  late final TabController _settingsTab;
  Timer? _volumeTimer;
  StreamSubscription? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _settingsTab = TabController(length: 2, vsync: this);
    
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'IPTV Player',
        logLevel: MPVLogLevel.warn,
      ),
    );

    if (_player.platform is NativePlayer) {
      final nativePlayer = _player.platform as NativePlayer;
      
      // ═══════════════════════════════════════════════════════════════
      // FIX CRASH CHANGEMENT RÉSOLUTION (AB1, LCI HD, etc.)
      // ═══════════════════════════════════════════════════════════════
      
      // 1. DÉCODAGE CPU UNIQUEMENT (évite corruption GPU)
      nativePlayer.setProperty('hwdec', 'no');
      
      // 2. FORCER RÉSOLUTION MAX DÈS LE DÉPART
      //    Empêche le passage 720p → 1080p qui recréé les textures
      nativePlayer.setProperty('hls-bitrate', 'max');
      
      // 3. ⭐ FIX PRINCIPAL : Désactiver le redimensionnement dynamique
      //    Force MPV à garder la même taille de frame interne
      nativePlayer.setProperty('video-sync', 'audio');
      nativePlayer.setProperty('framedrop', 'vo');
      
      // 4. ⭐ STABILISER LA SORTIE VIDÉO
      //    Évite la destruction/recréation de surfaces
      nativePlayer.setProperty('vo', 'libmpv');
      nativePlayer.setProperty('gpu-context', 'auto');
      
      // 5. BUFFER RÉSEAU AGRESSIF
      //    Donne du temps au décodeur pour s'adapter
      nativePlayer.setProperty('demuxer-max-bytes', '150MiB');
      nativePlayer.setProperty('demuxer-max-back-bytes', '75MiB');
      nativePlayer.setProperty('cache', 'yes');
      nativePlayer.setProperty('cache-secs', '30');
      
      // 6. RÉSEAU
      nativePlayer.setProperty('user-agent', 
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      nativePlayer.setProperty('vd-lavc-threads', '0');
      
      // 7. ⭐ DERNIER RECOURS : Désactiver le scaling GPU
      nativePlayer.setProperty('dscale', 'bilinear');
      nativePlayer.setProperty('scale', 'bilinear');
    }
    
    // ⚠️ DÉSACTIVER L'ACCÉLÉRATION MATÉRIELLE DU CONTROLLER
    // C'est la recréation de texture D3D11 qui crashe
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false, // ← CRITIQUE
      ),
    );
    
    _volume = _player.state.volume;
    
    _errorSubscription = _player.stream.error.listen((error) {
      developer.log('Erreur lecteur: $error', name: 'IPTV.Player');
      _handlePlayerError(error);
    });
    
    // Log des changements de résolution pour debug
    _player.stream.width.listen((w) => developer.log('Width: $w', name: 'IPTV.Resolution'));
    _player.stream.height.listen((h) => developer.log('Height: $h', name: 'IPTV.Resolution'));
    
    _loadSources();
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _player.dispose();
    _settingsTab.dispose();
    _volumeTimer?.cancel();
    super.dispose();
  }

  void _handlePlayerError(String error) {
    if (!mounted) return;
    setState(() => _lastError = error);
    _showSnackbar("Erreur: ${_currentChannel?.name}", isError: true);
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _currentChannel != null && _lastError != null) {
         _playChannel(_currentChannel!); 
      }
    });
  }

  Future<void> _loadSources() async {
    final sources = await StorageService.getSources();
    setState(() => _sources.addAll(sources));
    if (sources.isNotEmpty) _loadChannels(sources.first);
  }

  Future<void> _loadChannels(IptvSource source) async {
    setState(() {
      _isLoading = true;
      _currentSource = source;
    });

    try {
      final channels = await ApiService.getChannelsFromSource(source);
      if (mounted) {
        setState(() {
          _allChannels = channels;
          _filteredChannels = channels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar("Erreur: $e", isError: true);
      }
    }
  }

  Future<void> _playChannel(Channel channel) async {
    setState(() {
      _currentChannel = channel;
      _lastError = null;
    });

    try {
      // ⭐ IMPORTANT: Stop complet + petit délai avant nouveau flux
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await _player.open(Media(channel.url));
    } catch (e) {
      if (mounted) {
        setState(() => _lastError = e.toString());
        _showSnackbar("Impossible de lire: ${channel.name}", isError: true);
      }
    }
  }

  void _zapChannel(int direction) {
    if (_currentChannel == null || _filteredChannels.isEmpty) return;
    final index = _filteredChannels.indexOf(_currentChannel!);
    final newIndex = (index + direction).clamp(0, _filteredChannels.length - 1);
    if (newIndex != index) _playChannel(_filteredChannels[newIndex]);
  }

  void _adjustVolume(double delta) {
    final newVolume = (_player.state.volume + delta).clamp(0.0, 100.0);
    _player.setVolume(newVolume);
    setState(() {
      _volume = newVolume;
      _showVolume = true;
    });
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showVolume = false);
    });
  }

  void _filterChannels(String query) {
    setState(() {
      _filteredChannels = query.isEmpty
          ? _allChannels
          : _allChannels.where((c) => 
              c.name.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _showAudioTracks() {
    final tracks = _player.state.tracks.audio;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: tracks.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(
            tracks[i].title ?? tracks[i].language ?? "Piste ${i + 1}", 
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () {
            _player.setAudioTrack(tracks[i]);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _exportPlaylist() async {
    if (_allChannels.isEmpty) return;
    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporter M3U',
      fileName: '${_currentSource?.name ?? "playlist"}.m3u',
      allowedExtensions: ['m3u'],
      type: FileType.custom,
    );
    if (outputFile != null) _showSnackbar("Export réussi !");
  }

  Future<void> _addSource(String name, String url, SourceType type, 
      String user, String pass) async {
    final source = IptvSource(
      name: name, 
      type: type, 
      url: url, 
      username: user, 
      password: pass,
    );
    await StorageService.addSource(source);
    _sources.add(source);
    setState(() => _selectedTab = 0);
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MouseRegion(
        onHover: (event) {
          if (!_isFullScreen) return;
          setState(() => _showFloatingMenu = event.position.dx < 50);
        },
        child: Stack(
          children: [
            _buildMainContent(),
            if (_isFullScreen)
              FloatingMenu(
                isVisible: _showFloatingMenu,
                channels: _filteredChannels,
                selectedChannel: _currentChannel,
                onChannelTap: _playChannel,
                onSearch: _filterChannels,
              ),
            if (_showVolume)
              Positioned.fill(child: VolumeIndicator(volume: _volume)),
            if (_lastError != null) _buildErrorIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return Positioned(
      bottom: 80, left: 20, right: 20,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.9), 
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 15),
            const Text('Erreur de lecture', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white), 
              onPressed: () => setState(() => _lastError = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        if (!_isFullScreen) ...[_buildNavigationRail(), _buildSidePanel()],
        Expanded(
          child: VideoPlayerWidget(
            controller: _controller,
            currentChannel: _currentChannel,
            isFullScreen: _isFullScreen,
            onToggleFullScreen: () => setState(() => _isFullScreen = !_isFullScreen),
            onShowAudioTracks: _showAudioTracks,
            onPrevChannel: () => _zapChannel(-1),
            onNextChannel: () => _zapChannel(1),
            onVolumeChange: _adjustVolume,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      backgroundColor: const Color(0xFF1A1A1A),
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) => setState(() => _selectedTab = index),
      labelType: NavigationRailLabelType.all,
      leading: const Icon(Icons.tv, color: Colors.blue, size: 30),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.live_tv), label: Text('Chaînes')),
        NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Paramètres')),
      ],
    );
  }

  Widget _buildSidePanel() {
    return SizedBox(
      width: 320,
      child: Container(
        color: const Color(0xFF252525),
        child: _selectedTab == 0
            ? ChannelList(
                channels: _filteredChannels,
                selectedChannel: _currentChannel,
                isLoading: _isLoading,
                onChannelTap: _playChannel,
                onSearch: _filterChannels,
                currentSource: _currentSource,
                sources: _sources,
                onSourceChanged: _loadChannels,
              )
            : SettingsPanel(
                tabController: _settingsTab,
                hasChannels: _allChannels.isNotEmpty,
                onExportPlaylist: _exportPlaylist,
                onAddSource: _addSource,
              ),
      ),
    );
  }
}