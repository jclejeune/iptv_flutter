import 'dart:async';
import 'dart:io';
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
    _settingsTab = TabController(length: 2, vsync: this); // ✅ MODIFIÉ : 2 onglets
    
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'IPTV Player',
        logLevel: MPVLogLevel.warn,
      ),
    );

    if (_player.platform is NativePlayer) {
      final nativePlayer = _player.platform as NativePlayer;
      
      nativePlayer.setProperty('hwdec', 'no');
      nativePlayer.setProperty('hls-bitrate', 'max');
      nativePlayer.setProperty('video-sync', 'audio');
      nativePlayer.setProperty('framedrop', 'vo');
      nativePlayer.setProperty('vo', 'gpu');
      nativePlayer.setProperty('gpu-api', 'opengl');
      nativePlayer.setProperty('gpu-context', 'win');
      nativePlayer.setProperty('demuxer-max-bytes', '200MiB');
      nativePlayer.setProperty('demuxer-max-back-bytes', '100MiB');
      nativePlayer.setProperty('cache', 'yes');
      nativePlayer.setProperty('cache-secs', '60');
      nativePlayer.setProperty('user-agent', 
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      nativePlayer.setProperty('http-header-fields', 'Connection: keep-alive');
      nativePlayer.setProperty('network-timeout', '30');
      nativePlayer.setProperty('vd-lavc-threads', '4');
      nativePlayer.setProperty('scale', 'bilinear');
      nativePlayer.setProperty('dscale', 'bilinear');
      nativePlayer.setProperty('cscale', 'bilinear');
      nativePlayer.setProperty('audio-buffer', '1.0');
      nativePlayer.setProperty('video-latency-hacks', 'yes');
    }
    
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
      ),
    );
    
    _volume = _player.state.volume;
    
    _errorSubscription = _player.stream.error.listen((error) {
      developer.log('Erreur lecteur: $error', name: 'IPTV.Player');
      _handlePlayerError(error);
    });
    
    _player.stream.buffering.listen((buffering) {
      if (buffering) developer.log('Buffering...', name: 'IPTV.Player');
    });
    
    _player.stream.width.listen((w) => 
      developer.log('Résolution: ${w}x${_player.state.height}', name: 'IPTV.Player'));
    
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
      if (mounted && _filteredChannels.length > 1) {
        _zapChannel(1);
      }
    });
  }

  // ✅ MODIFIÉ : Recharger les sources
  Future<void> _loadSources() async {
    final sources = await StorageService.getSources();
    setState(() {
      _sources.clear();
      _sources.addAll(sources);
    });
    if (sources.isNotEmpty && _currentSource == null) {
      _loadChannels(sources.first);
    }
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
        developer.log('${channels.length} chaînes chargées', name: 'IPTV');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar("Erreur: $e", isError: true);
      }
    }
  }

  Future<void> _playChannel(Channel channel, {int retryCount = 0}) async {
    setState(() {
      _currentChannel = channel;
      _lastError = null;
    });

    try {
      developer.log('Lecture: ${channel.name} (tentative ${retryCount + 1}/3)', name: 'IPTV.Play');
      
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 200));
      await _player.open(Media(channel.url));
      
      await _player.stream.playing
          .firstWhere((playing) => playing)
          .timeout(const Duration(seconds: 10));
      
      developer.log('✓ Lecture démarrée', name: 'IPTV.Play');
      
    } catch (e) {
      developer.log('✗ Erreur (tentative ${retryCount + 1})', name: 'IPTV.Error', error: e);
      
      if (retryCount < 2 && mounted) {
        developer.log('Retry dans 2s...', name: 'IPTV.Play');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) return _playChannel(channel, retryCount: retryCount + 1);
      }
      
      if (mounted) {
        setState(() => _lastError = e.toString());
        _showSnackbar(
          "Impossible de lire: ${channel.name}\nPassage à la suivante...",
          isError: true,
        );
        
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _filteredChannels.length > 1) _zapChannel(1);
        });
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
    if (_allChannels.isEmpty) {
      _showSnackbar("Aucune chaîne à exporter", isError: true);
      return;
    }

    try {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter M3U',
        fileName: '${_currentSource?.name ?? "playlist"}.m3u',
        allowedExtensions: ['m3u'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final buffer = StringBuffer('#EXTM3U\n');

        for (var ch in _allChannels) {
          buffer.write('#EXTINF:-1');
          if (ch.logoUrl != null) buffer.write(' tvg-logo="${ch.logoUrl}"');
          if (ch.group != null) buffer.write(' group-title="${ch.group}"');
          buffer.write(',${ch.name}\n${ch.url}\n');
        }

        await File(outputFile).writeAsString(buffer.toString());
        
        developer.log('Playlist exportée: $outputFile (${_allChannels.length} chaînes)', name: 'IPTV');
        _showSnackbar("Export réussi ! ${_allChannels.length} chaînes");
      }
    } catch (e) {
      developer.log('Erreur export', name: 'IPTV.Error', error: e);
      _showSnackbar("Erreur d'export: $e", isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 5 : 3),
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
            const Expanded(
              child: Text('Erreur de lecture\nPassage à la chaîne suivante...', 
                style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
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
                sources: _sources, // ✅ AJOUTÉ
                onSourcesChanged: _loadSources, // ✅ AJOUTÉ
              ),
      ),
    );
  }
}