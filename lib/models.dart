class Channel {
  final String id;
  final String name;
  final String url;
  final String? logoUrl;
  final String? group;

  Channel({
    required this.id,
    required this.name,
    required this.url,
    this.logoUrl,
    this.group,
  });

  // Pour convertir en JSON (sauvegarde) si besoin
  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Inconnu',
      url: json['url'] ?? '',
      logoUrl: json['logo'],
      group: json['group'],
    );
  }
}

// Type de source (Fichier M3U ou Xtream Codes)
enum SourceType { m3u, xtream }

class IptvSource {
  final String name; // Nom donné par l'utilisateur (ex: "Mon Serveur")
  final SourceType type;
  final String url; // URL M3U ou URL Serveur Xtream
  final String username; // Pour Xtream
  final String password; // Pour Xtream

  IptvSource({
    required this.name,
    required this.type,
    required this.url,
    this.username = '',
    this.password = '',
  });

  // Convertir en texte pour sauvegarder dans le téléphone/PC
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.toString(),
        'url': url,
        'username': username,
        'password': password,
      };

  factory IptvSource.fromJson(Map<String, dynamic> json) {
    return IptvSource(
      name: json['name'],
      type: json['type'] == 'SourceType.xtream' ? SourceType.xtream : SourceType.m3u,
      url: json['url'],
      username: json['username'] ?? '',
      password: json['password'] ?? '',
    );
  }
}