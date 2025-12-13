import 'dart:convert';
//import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart'; // Le téléchargeur puissant
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p; // Pour gérer les noms de fichiers
import 'models.dart';

class ApiService {
  // --- GESTION DES SOURCES (M3U & XTREAM) ---

  // Fonction principale qui décide comment charger selon le type
  static Future<List<Channel>> getChannelsFromSource(IptvSource source) async {
    if (source.type == SourceType.m3u) {
      return _parseM3u(source.url);
    } else {
      return _fetchXtream(source);
    }
  }

  // 1. Logique M3U (Classique)
  static Future<List<Channel>> _parseM3u(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception("Erreur HTTP");

      String content = utf8.decode(response.bodyBytes, allowMalformed: true);
      List<String> lines = content.split('\n');
      List<Channel> channels = [];

      String? currentName;
      String? currentLogo;
      String? currentGroup;

      for (String line in lines) {
        line = line.trim();
        if (line.startsWith('#EXTINF')) {
          // Extraction Nom
          List<String> parts = line.split(',');
          currentName = parts.length > 1 ? parts.sublist(1).join(',').trim() : "Sans nom";
          
          // Extraction Logo (tvg-logo="...")
          final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
          if (logoMatch != null) currentLogo = logoMatch.group(1);

          // Extraction Groupe (group-title="...")
          final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
          currentGroup = groupMatch != null ? groupMatch.group(1) : "Général";

        } else if (line.isNotEmpty && !line.startsWith('#')) {
          if (currentName != null) {
            channels.add(Channel(
              id: line, // On utilise l'URL comme ID unique temporaire
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

  // 2. Logique Xtream Codes (API)
  static Future<List<Channel>> _fetchXtream(IptvSource source) async {
    // Construction de l'URL API Xtream
    // Format: http://url/player_api.php?username=X&password=Y&action=get_live_streams
    final baseUrl = source.url.endsWith('/') ? source.url : '${source.url}/';
    final apiUrl = "${baseUrl}player_api.php?username=${source.username}&password=${source.password}&action=get_live_streams";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        
        return jsonList.map((json) {
          // L'URL du flux Xtream est : http://url/live/user/pass/streamID.ts
          final streamId = json['stream_id'].toString();
          final streamUrl = "${baseUrl}live/${source.username}/${source.password}/$streamId.ts";
          
          return Channel(
            id: streamId,
            name: json['name'] ?? 'Inconnu',
            url: streamUrl, // C'est ici qu'on construit le lien final
            logoUrl: json['stream_icon'],
            group: json['category_id'].toString(), // On pourrait récupérer le nom de la catégorie avec une autre requête
          );
        }).toList();
      } else {
        throw Exception("Erreur connexion Xtream");
      }
    } catch (e) {
      throw Exception("Erreur Xtream: $e");
    }
  }
}

// --- GESTION DE LA SAUVEGARDE (SOURCES & DOSSIER) ---

class StorageService {
  static const String keySources = 'iptv_sources';
  static const String keyRecordPath = 'record_path';

  // Récupérer les sources sauvegardées
  static Future<List<IptvSource>> getSources() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sourcesJson = prefs.getString(keySources);
    if (sourcesJson == null) return [];
    
    List<dynamic> decoded = json.decode(sourcesJson);
    return decoded.map((e) => IptvSource.fromJson(e)).toList();
  }

  // Ajouter une source
  static Future<void> addSource(IptvSource source) async {
    final prefs = await SharedPreferences.getInstance();
    List<IptvSource> current = await getSources();
    current.add(source);
    
    String encoded = json.encode(current.map((e) => e.toJson()).toList());
    await prefs.setString(keySources, encoded);
  }

    // Mettre à jour une source existante
  static Future<void> updateSource(int index, IptvSource newSource) async {
    final prefs = await SharedPreferences.getInstance();
    List<IptvSource> current = await getSources();
    
    if (index >= 0 && index < current.length) {
      current[index] = newSource; // On remplace l'ancienne par la nouvelle
      String encoded = json.encode(current.map((e) => e.toJson()).toList());
      await prefs.setString(keySources, encoded);
    }
  }
  
  // Supprimer une source
  static Future<void> removeSource(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<IptvSource> current = await getSources();
    current.removeAt(index);
     String encoded = json.encode(current.map((e) => e.toJson()).toList());
    await prefs.setString(keySources, encoded);
  }

  // Gérer le dossier d'enregistrement
  static Future<String?> getRecordingPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRecordPath);
  }

  static Future<void> setRecordingPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyRecordPath, path);
  }
}

// --- GESTION DE L'ENREGISTREMENT (REC) ---

class RecorderService {
  static final Dio _dio = Dio();
  // Pour pouvoir annuler l'enregistrement en cours
  static CancelToken? _cancelToken;
  static bool isRecording = false;

  static Future<void> startRecording(Channel channel, String folderPath, Function(String) onError) async {
    if (isRecording) return;

    try {
      isRecording = true;
      _cancelToken = CancelToken();

      // Création du nom de fichier : "TF1_2023-10-27_20-00.ts"
      final now = DateTime.now();
      String safeName = channel.name.replaceAll(RegExp(r'[^\w\s]+'), ''); // Enlève les caractères bizarres
      String fileName = "${safeName}_${now.hour}-${now.minute}-${now.second}.ts";
      String savePath = p.join(folderPath, fileName);

      print("Début enregistrement vers : $savePath");

      await _dio.download(
        channel.url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          // On pourrait afficher la taille ici, mais pour du streaming live 'total' est souvent -1
        },
      );
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        print("Enregistrement arrêté par l'utilisateur.");
      } else {
        isRecording = false;
        onError("Erreur REC: $e");
      }
    }
  }

  static void stopRecording() {
    if (isRecording && _cancelToken != null) {
      _cancelToken!.cancel("Stop demandé");
      isRecording = false;
      print("Stop enregistrement.");
    }
  }
}