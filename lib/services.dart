import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'models.dart';

// === API SERVICE ===

class ApiService {
  static Future<List<Channel>> getChannelsFromSource(IptvSource source) async {
    return source.type == SourceType.m3u
        ? _parseM3u(source.url)
        : _fetchXtream(source);
  }

  // M3U Parser
  static Future<List<Channel>> _parseM3u(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception("Erreur HTTP ${response.statusCode}");
      }

      final content = utf8.decode(response.bodyBytes, allowMalformed: true);
      final lines = content.split('\n');
      final channels = <Channel>[];

      String? currentName;
      String? currentLogo;
      String? currentGroup;

      for (var line in lines) {
        line = line.trim();
        
        if (line.startsWith('#EXTINF')) {
          final parts = line.split(',');
          currentName = parts.length > 1 
              ? parts.sublist(1).join(',').trim() 
              : "Sans nom";

          final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
          currentLogo = logoMatch?.group(1);

          final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
          currentGroup = groupMatch?.group(1) ?? "Général";
        } 
        else if (line.isNotEmpty && !line.startsWith('#')) {
          if (currentName != null) {
            channels.add(Channel(
              id: line,
              name: currentName,
              url: line,
              logoUrl: currentLogo,
              group: currentGroup,
            ));
            currentName = null;
            currentLogo = null;
          }
        }
      }
      
      return channels;
    } catch (e) {
      throw Exception("Impossible de lire le M3U : $e");
    }
  }

  // Xtream Codes API
  static Future<List<Channel>> _fetchXtream(IptvSource source) async {
    final baseUrl = source.url.endsWith('/') ? source.url : '${source.url}/';
    final apiUrl = "${baseUrl}player_api.php"
        "?username=${source.username}"
        "&password=${source.password}"
        "&action=get_live_streams";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      
      if (response.statusCode != 200) {
        throw Exception("Erreur connexion Xtream (${response.statusCode})");
      }

      final jsonList = json.decode(response.body) as List<dynamic>;

      return jsonList.map((json) {
        final streamId = json['stream_id'].toString();
        final streamUrl = "${baseUrl}live/${source.username}/${source.password}/$streamId.ts";

        return Channel(
          id: streamId,
          name: json['name'] ?? 'Inconnu',
          url: streamUrl,
          logoUrl: json['stream_icon'],
          group: json['category_id']?.toString(),
        );
      }).toList();
    } catch (e) {
      throw Exception("Erreur Xtream: $e");
    }
  }
}

// === STORAGE SERVICE ===

class StorageService {
  static const String _keySources = 'iptv_sources';
  static const String _keyRecordPath = 'record_path';

  // Sources
  static Future<List<IptvSource>> getSources() async {
    final prefs = await SharedPreferences.getInstance();
    final sourcesJson = prefs.getString(_keySources);
    
    if (sourcesJson == null) return [];

    final decoded = json.decode(sourcesJson) as List<dynamic>;
    return decoded.map((e) => IptvSource.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> addSource(IptvSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getSources();
    current.add(source);

    final encoded = json.encode(current.map((e) => e.toJson()).toList());
    await prefs.setString(_keySources, encoded);
  }

  static Future<void> updateSource(int index, IptvSource newSource) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getSources();

    if (index >= 0 && index < current.length) {
      current[index] = newSource;
      final encoded = json.encode(current.map((e) => e.toJson()).toList());
      await prefs.setString(_keySources, encoded);
    }
  }

  static Future<void> removeSource(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getSources();
    
    if (index >= 0 && index < current.length) {
      current.removeAt(index);
      final encoded = json.encode(current.map((e) => e.toJson()).toList());
      await prefs.setString(_keySources, encoded);
    }
  }

  // Recording Path
  static Future<String?> getRecordingPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRecordPath);
  }

  static Future<void> setRecordingPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecordPath, path);
  }
}

// === RECORDER SERVICE ===

class RecorderService {
  static final Dio _dio = Dio();
  static CancelToken? _cancelToken;
  static bool isRecording = false;

  static Future<void> startRecording(
    Channel channel,
    String folderPath,
    Function(String) onError,
  ) async {
    if (isRecording) return;

    try {
      isRecording = true;
      _cancelToken = CancelToken();

      final now = DateTime.now();
      final safeName = channel.name.replaceAll(RegExp(r'[^\w\s]+'), '');
      final fileName = "${safeName}_${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}.ts";
      final savePath = p.join(folderPath, fileName);

      await _dio.download(
        channel.url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          // Progress tracking (si besoin)
        },
      );
      
      isRecording = false;
    } catch (e) {
      isRecording = false;
      
      if (e is DioException && CancelToken.isCancel(e)) {
        // Enregistrement arrêté volontairement
        return;
      }
      
      onError("Erreur d'enregistrement: $e");
    }
  }

  static void stopRecording() {
    if (isRecording && _cancelToken != null) {
      _cancelToken!.cancel("Arrêt demandé par l'utilisateur");
      isRecording = false;
    }
  }
}