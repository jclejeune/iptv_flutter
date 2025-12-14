import 'package:flutter/material.dart';
import '../models.dart';

class ChannelList extends StatelessWidget {
  final List<Channel> channels;
  final Channel? selectedChannel;
  final bool isLoading;
  final bool isTransparent;
  final Function(Channel) onChannelTap;
  final Function(String) onSearch;
  final IptvSource? currentSource;
  final List<IptvSource> sources;
  final Function(IptvSource)? onSourceChanged;

  const ChannelList({
    super.key,
    required this.channels,
    this.selectedChannel,
    this.isLoading = false,
    this.isTransparent = false,
    required this.onChannelTap,
    required this.onSearch,
    this.currentSource,
    this.sources = const [],
    this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isTransparent && onSourceChanged != null) _buildSourceSelector(),
        _buildSearchBar(),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildChannelListView(),
        ),
      ],
    );
  }

  Widget _buildSourceSelector() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: const Color(0xFF303030),
      child: DropdownButtonFormField<IptvSource>(
        decoration: const InputDecoration(
          labelText: "Playlist",
          border: OutlineInputBorder(),
        ),
        // ✅ Utilise initialValue au lieu de value
        initialValue: sources.contains(currentSource) ? currentSource : null,
        isExpanded: true,
        items: sources
            .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
            .toList(),
        onChanged: (s) {
          if (s != null) onSourceChanged?.call(s);
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: "Rechercher...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: isTransparent ? Colors.white10 : const Color(0xFF333333),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildChannelListView() {
    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (ctx, i) {
        final channel = channels[i];
        final isSelected = selectedChannel?.id == channel.id;

        return Container(
          // ✅ Utilise withValues au lieu de withOpacity
          color: isSelected
              ? Colors.blueAccent.withValues(alpha: isTransparent ? 0.4 : 0.2)
              : Colors.transparent,
          child: ListTile(
            dense: true,
            leading: channel.logoUrl != null
                ? Image.network(
                    channel.logoUrl!,
                    width: 30,
                    errorBuilder: (_, __, ___) => const Icon(Icons.tv),
                  )
                : const Icon(Icons.tv),
            title: Text(
              channel.name,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () => onChannelTap(channel),
          ),
        );
      },
    );
  }
}