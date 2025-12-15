// lib/widgets/playlist_manager.dart

import 'package:flutter/material.dart';
import '../models.dart';
import '../services.dart';

class PlaylistManager extends StatefulWidget {
  final List<IptvSource> sources;
  final Function() onSourcesChanged;

  const PlaylistManager({
    super.key,
    required this.sources,
    required this.onSourcesChanged,
  });

  @override
  State<PlaylistManager> createState() => _PlaylistManagerState();
}

class _PlaylistManagerState extends State<PlaylistManager> {
  
  // --- DIALOGUE D'AJOUT ---
  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    SourceType selectedType = SourceType.m3u;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter une playlist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 10),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SourceType>(
                      value: selectedType,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: SourceType.m3u, child: Text('M3U')),
                        DropdownMenuItem(value: SourceType.xtream, child: Text('Xtream')),
                      ],
                      onChanged: (type) {
                        if (type != null) {
                          setDialogState(() => selectedType = type);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                if (selectedType == SourceType.xtream) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Utilisateur',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  final source = IptvSource(
                    name: nameCtrl.text,
                    type: selectedType,
                    url: urlCtrl.text,
                    username: userCtrl.text,
                    password: passCtrl.text,
                  );
                  
                  // Opération asynchrone
                  await StorageService.addSource(source);
                  widget.onSourcesChanged();
                  
                  // ✅ CORRECTION OBLIGATOIRE : Vérifier si le widget est encore là
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIALOGUE DE MODIFICATION ---
  void _showEditDialog(int index, IptvSource source) {
    final nameCtrl = TextEditingController(text: source.name);
    final urlCtrl = TextEditingController(text: source.url);
    final userCtrl = TextEditingController(text: source.username);
    final passCtrl = TextEditingController(text: source.password);
    SourceType selectedType = source.type;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier la playlist'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 10),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SourceType>(
                      value: selectedType,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: SourceType.m3u, child: Text('M3U')),
                        DropdownMenuItem(value: SourceType.xtream, child: Text('Xtream')),
                      ],
                      onChanged: (type) {
                        if (type != null) {
                          setDialogState(() => selectedType = type);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                if (selectedType == SourceType.xtream) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Utilisateur',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  final updatedSource = IptvSource(
                    name: nameCtrl.text,
                    type: selectedType,
                    url: urlCtrl.text,
                    username: userCtrl.text,
                    password: passCtrl.text,
                  );

                  // Opération asynchrone
                  await StorageService.updateSource(index, updatedSource);
                  widget.onSourcesChanged();
                  
                  // ✅ CORRECTION OBLIGATOIRE
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIALOGUE DE SUPPRESSION ---
  void _confirmDelete(int index, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "$name" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // Opération asynchrone
              await StorageService.removeSource(index);
              widget.onSourcesChanged();
              
              // ✅ CORRECTION : Utiliser ctx (le context du dialog) au lieu de context
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const Text(
                'Gestion des Playlists',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.sources.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune playlist\nCliquez sur "Ajouter" pour commencer',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.sources.length,
                  itemBuilder: (ctx, i) {
                    final source = widget.sources[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: source.type == SourceType.m3u
                              ? Colors.blue
                              : Colors.orange,
                          child: Icon(
                            source.type == SourceType.m3u
                                ? Icons.link
                                : Icons.cloud,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(source.name),
                        subtitle: Text(
                          source.type == SourceType.m3u ? 'M3U' : 'Xtream',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditDialog(i, source),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(i, source.name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}