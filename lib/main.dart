import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A falha ao iniciar o serviço de notificações de áudio não deve impedir
  // que a interface principal seja aberta.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.cobrasong.audio',
      androidNotificationChannelName: 'COBRASONG • Reprodução',
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 8));
  } catch (error, stackTrace) {
    debugPrint('COBRASONG: serviço de áudio indisponível na inicialização: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const CobraSongApp());
}

const Color bg = Color(0xFF090A10);
const Color panel = Color(0xFF141521);
const Color purple = Color(0xFF9B5CFF);
const Color neon = Color(0xFFB8FF45);
const Color muted = Color(0xFF9293A5);

class CobraSongApp extends StatelessWidget {
  const CobraSongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'COBRASONG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: purple, secondary: neon, surface: panel,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainShell(),
    );
  }
}

class Track {
  final String title, artist;
  final Color color;
  const Track(this.title, this.artist, this.color);
}

const tracks = [
  Track('Midnight City', 'M83 • Demonstração', Color(0xFF6C4CFF)),
  Track('Afterglow', 'Nova Pulse • Demonstração', Color(0xFFB84DFF)),
  Track('Neon Dreams', 'Kairo • Demonstração', Color(0xFF2DAD91)),
  Track('Velvet Sky', 'Luna Park • Demonstração', Color(0xFFDB7A42)),
];


class AudiusTrack {
  final String id;
  final String title;
  final String artist;
  final String? artwork;
  final int duration;
  final bool downloadable;
  final bool isStreamable;
  final String source;
  final String? audioUrl;

  const AudiusTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.artwork,
    required this.duration,
    this.downloadable = false,
    this.isStreamable = true,
    this.source = 'Audius',
    this.audioUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'user': {'name': artist},
    'artwork': {'150x150': artwork}, 'duration': duration,
    'downloadable': downloadable, 'isStreamable': isStreamable,
    'source': source, 'audioUrl': audioUrl,
  };

  factory AudiusTrack.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? json['user'] as Map : const {};
    final artworkData = json['artwork'] is Map ? json['artwork'] as Map : const {};
    return AudiusTrack(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Faixa sem título'}',
      artist: '${user['name'] ?? 'Artista Audius'}',
      artwork: artworkData['150x150']?.toString() ?? artworkData['1000x1000']?.toString(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      downloadable: json['downloadable'] == true,
      isStreamable: json['isStreamable'] != false && json['is_streamable'] != false,
      source: '${json['source'] ?? 'Audius'}',
      audioUrl: json['audioUrl']?.toString(),
    );
  }
}

class AudiusService {
  static const _bases = [
    'https://api.audius.co/v1',
    'https://discoveryprovider.audius.co/v1',
  ];

  Future<List<AudiusTrack>> _getTracks(String path, Map<String, String> params) async {
    http.Response? response;
    Object? lastError;
    for (final base in _bases) {
      try {
        final uri = Uri.parse('$base/$path').replace(queryParameters: {
          ...params,
          'limit': '20',
          'app_name': 'COBRASONG',
        });
        final candidate = await http.get(uri).timeout(const Duration(seconds: 20));
        if (candidate.statusCode == 200) {
          response = candidate;
          break;
        }
        lastError = Exception('Catálogo respondeu com status ${candidate.statusCode}.');
      } catch (error) {
        lastError = error;
      }
    }
    if (response == null) {
      throw Exception('Não foi possível acessar o catálogo. ${lastError ?? 'Tente novamente.'}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => AudiusTrack.fromJson(Map<String, dynamic>.from(item)))
        .where((track) => track.id.isNotEmpty && track.isStreamable)
        .toList();
  }

  Future<List<AudiusTrack>> search(String query, {int offset = 0}) =>
      _getTracks('tracks/search', {'query': query, 'offset': '$offset'});

  Future<List<AudiusTrack>> trending({int offset = 0}) =>
      _getTracks('tracks/trending', {'time': 'week', 'offset': '$offset'});

  // Use a Discovery Provider for stream resolution instead of relying on one API gateway.
  String streamUrl(String trackId) =>
      'https://discoveryprovider.audius.co/v1/tracks/${Uri.encodeComponent(trackId)}/stream?app_name=COBRASONG';

  String downloadUrl(String trackId) =>
      'https://api.audius.co/v1/tracks/${Uri.encodeComponent(trackId)}/download?app_name=COBRASONG';
}

class ITunesCatalogService {
  Future<List<AudiusTrack>> search(String query) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': query, 'entity': 'song', 'limit': '20', 'country': 'BR',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) {
      throw Exception('Catálogo iTunes indisponível (${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['results'];
    if (items is! List) return [];
    return items.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final preview = item['previewUrl']?.toString();
      final id = item['trackId']?.toString() ?? '';
      if (preview == null || preview.isEmpty || id.isEmpty) return null;
      return AudiusTrack(
        id: 'itunes:$id',
        title: item['trackName']?.toString() ?? 'Faixa sem título',
        artist: item['artistName']?.toString() ?? 'Artista',
        artwork: item['artworkUrl100']?.toString(),
        duration: 30,
        downloadable: false,
        isStreamable: true,
        source: 'iTunes • prévia',
        audioUrl: preview,
      );
    }).whereType<AudiusTrack>().toList();
  }
}

class MusicPlaylist {
  final String id;
  String name;
  final List<String> trackIds;
  MusicPlaylist({required this.id, required this.name, List<String>? trackIds}) : trackIds = trackIds ?? [];
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'trackIds': trackIds};
  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: '${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
    name: '${json['name'] ?? 'Minha playlist'}',
    trackIds: (json['trackIds'] as List? ?? []).map((e) => e.toString()).toList(),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;
  String? _searchRequest;
  int _searchRequestId = 0;
  bool playing = false;
  int _repeatModeIndex = 0; // 0 = desligado, 1 = repetir fila, 2 = repetir faixa
  int currentTrack = 0;
  AudiusTrack? currentAudiusTrack;
  late final AudioPlayer audioPlayer;
  late final StreamSubscription<int?> _indexSubscription;
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  List<AudiusTrack> _playQueue = [];
  int _queueIndex = 0;
  final Set<String> favoriteIds = {};
  final Map<String, int> ratings = {};
  final Map<String, AudiusTrack> savedTracks = {};
  final Map<String, String> downloadedPaths = {};
  final Set<String> downloadingIds = {};
  final List<MusicPlaylist> playlists = [];
  final pages = const ['Início', 'Explorar', 'Salas', 'Jogos', 'Biblioteca', 'Cartas'];

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    _indexSubscription = audioPlayer.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= _playQueue.length || !mounted) return;
      setState(() {
        _queueIndex = index;
        currentAudiusTrack = _playQueue[index];
      });
    });
    _playerStateSubscription = audioPlayer.playerStateStream.listen((state) {
      if (mounted && playing != state.playing) {
        setState(() => playing = state.playing);
      }
    });
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final fav = jsonDecode(prefs.getString('cobra_favorites') ?? '[]') as List;
      final rate = jsonDecode(prefs.getString('cobra_ratings') ?? '{}') as Map;
      final lists = jsonDecode(prefs.getString('cobra_playlists') ?? '[]') as List;
      final saved = jsonDecode(prefs.getString('cobra_saved_tracks') ?? '{}') as Map;
      final downloads = jsonDecode(prefs.getString('cobra_downloads') ?? '{}') as Map;
      if (!mounted) return;
      setState(() {
        favoriteIds.addAll(fav.map((e) => e.toString()));
        ratings.addAll(rate.map((k,v) => MapEntry(k.toString(), (v as num).toInt())));
        playlists.addAll(lists.whereType<Map>().map((e) => MusicPlaylist.fromJson(Map<String,dynamic>.from(e))));
        for (final e in saved.entries) {
          if (e.value is Map) savedTracks[e.key.toString()] = AudiusTrack.fromJson(Map<String,dynamic>.from(e.value as Map));
        }
        downloadedPaths.addAll(downloads.map((k, v) => MapEntry(k.toString(), v.toString())));
      });
    } catch (_) {}
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cobra_favorites', jsonEncode(favoriteIds.toList()));
    await prefs.setString('cobra_ratings', jsonEncode(ratings));
    await prefs.setString('cobra_playlists', jsonEncode(playlists.map((p) => p.toJson()).toList()));
    await prefs.setString('cobra_saved_tracks', jsonEncode(savedTracks.map((k,v) => MapEntry(k,v.toJson()))));
    await prefs.setString('cobra_downloads', jsonEncode(downloadedPaths));
  }

  void _rememberTrack(AudiusTrack track) { savedTracks[track.id] = track; _saveLibrary(); }

  void _toggleFavorite(AudiusTrack track) {
    setState(() {
      _rememberTrack(track);
      if (!favoriteIds.add(track.id)) favoriteIds.remove(track.id);
    });
    _saveLibrary();
  }

  Future<void> _rateTrack(AudiusTrack track) async {
    _rememberTrack(track);
    final value = await showDialog<int>(context: context, builder: (dialogContext) {
      int selected = ratings[track.id] ?? 0;
      return StatefulBuilder(builder: (context, refresh) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Avaliar música'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
            onPressed: () => refresh(() => selected = i + 1),
            icon: Icon(i < selected ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFFFC857), size: 30),
          ))),
          Text(selected == 0 ? 'Escolha de 1 a 5 estrelas' : '$selected de 5 estrelas', style: const TextStyle(color: muted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: selected == 0 ? null : () => Navigator.pop(dialogContext, selected), child: const Text('Salvar')),
        ],
      ));
    });
    if (value != null && mounted) { setState(() => ratings[track.id] = value); _saveLibrary(); }
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      backgroundColor: panel,
      title: const Text('Nova playlist'),
      content: TextField(controller: controller, autofocus: true, maxLength: 40, decoration: const InputDecoration(hintText: 'Nome da playlist')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        FilledButton(onPressed: () { final v = controller.text.trim(); if (v.isNotEmpty) Navigator.pop(dialogContext, v); }, child: const Text('Criar')),
      ],
    ));
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() => playlists.add(MusicPlaylist(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.trim())));
    _saveLibrary();
  }

  Future<void> _addToPlaylist(AudiusTrack track) async {
    _rememberTrack(track);
    if (playlists.isEmpty) await _createPlaylist();
    if (!mounted || playlists.isEmpty) return;
    final chosen = await showModalBottomSheet<String>(context: context, backgroundColor: panel, builder: (sheetContext) => SafeArea(child: ListView(
      shrinkWrap: true,
      children: [
        const ListTile(title: Text('Adicionar à playlist', style: TextStyle(fontWeight: FontWeight.bold))),
        for (final p in playlists) ListTile(
          leading: const Icon(Icons.queue_music_rounded, color: neon),
          title: Text(p.name), subtitle: Text('${p.trackIds.length} músicas'),
          onTap: () => Navigator.pop(sheetContext, p.id),
        ),
      ],
    )));
    if (chosen == null || !mounted) return;
    setState(() { final p = playlists.firstWhere((e) => e.id == chosen); if (!p.trackIds.contains(track.id)) p.trackIds.add(track.id); });
    _saveLibrary();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Música adicionada à playlist!')));
  }

  @override
  void dispose() {
    _indexSubscription.cancel();
    _playerStateSubscription.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  void playTrack(int index) {
    audioPlayer.stop();
    setState(() {
      currentAudiusTrack = null;
      currentTrack = index;
      playing = true;
    });
  }

  Future<void> _downloadTrack(AudiusTrack track) async {
    if (!track.downloadable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta faixa não está liberada para download pelo criador.')));
      return;
    }
    final alreadyDownloaded = downloadedPaths.containsKey(track.id) &&
        await File(downloadedPaths[track.id]!).exists();
    if (!mounted) return;
    if (alreadyDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Essa música já está salva para ouvir offline.')));
      return;
    }
    setState(() => downloadingIds.add(track.id));
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(AudiusService().downloadUrl(track.id)));
      final response = await client.send(request).timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        throw Exception('Download indisponível (HTTP ${response.statusCode}).');
      }
      final directory = await getApplicationSupportDirectory();
      final safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${directory.path}/cobra_$safeId.mp3');
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (!mounted) return;
      setState(() {
        savedTracks[track.id] = track;
        downloadedPaths[track.id] = file.path;
        downloadingIds.remove(track.id);
      });
      await _saveLibrary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('“${track.title}” salva para ouvir offline!')));
    } catch (error) {
      if (!mounted) return;
      setState(() => downloadingIds.remove(track.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível baixar: $error')));
    } finally {
      client.close();
      if (mounted && downloadingIds.contains(track.id)) setState(() => downloadingIds.remove(track.id));
    }
  }

  Future<void> _playDownloaded(AudiusTrack track) async {
    final path = downloadedPaths[track.id];
    if (path == null || !await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo offline não encontrado. Baixe a música novamente.')));
      return;
    }
    try {
      final offlineQueue = downloadedPaths.keys
          .map((id) => savedTracks[id])
          .whereType<AudiusTrack>()
          .where((item) => downloadedPaths[item.id] != null)
          .toList();
      _playQueue = offlineQueue.isEmpty ? [track] : offlineQueue;
      _queueIndex = _playQueue.indexWhere((item) => item.id == track.id);
      if (_queueIndex < 0) {
        _playQueue = [track];
        _queueIndex = 0;
      }
      final sources = _playQueue.map((item) => AudioSource.uri(
        Uri.file(downloadedPaths[item.id]!),
        tag: MediaItem(
          id: item.id,
          title: item.title,
          artist: item.artist,
          artUri: item.artwork == null ? null : Uri.tryParse(item.artwork!),
        ),
      )).toList();
      final source = sources.length == 1 ? sources.first : ConcatenatingAudioSource(children: sources);
      await audioPlayer.setAudioSource(source, initialIndex: _queueIndex);
      if (!mounted) return;
      setState(() { currentAudiusTrack = track; playing = true; });
      await audioPlayer.play();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível tocar offline: $error')));
    }
  }

  Future<void> _removeDownload(AudiusTrack track) async {
    if (_playQueue.any((item) => item.id == track.id)) {
      await audioPlayer.stop();
      _playQueue = [];
      _queueIndex = 0;
      if (mounted) setState(() { currentAudiusTrack = null; playing = false; });
    }
    final path = downloadedPaths[track.id];
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (!mounted) return;
    setState(() => downloadedPaths.remove(track.id));
    await _saveLibrary();
  }

  Future<void> playAudiusTrack(AudiusTrack track) async {
    if (_playQueue.isEmpty || !_playQueue.any((item) => item.id == track.id)) {
      _playQueue = [track];
    }
    _queueIndex = _playQueue.indexWhere((item) => item.id == track.id);
    if (_queueIndex < 0) {
      _playQueue = [track];
      _queueIndex = 0;
    }
    setState(() {
      currentAudiusTrack = track;
      playing = true;
    });
    try {
      final sources = _playQueue.map((item) => AudioSource.uri(
        Uri.parse(item.audioUrl ?? AudiusService().streamUrl(item.id)),
        tag: MediaItem(
          id: item.id,
          title: item.title,
          artist: item.artist,
          artUri: item.artwork == null ? null : Uri.tryParse(item.artwork!),
        ),
      )).toList();
      final source = sources.length == 1 ? sources.first : ConcatenatingAudioSource(children: sources);
      await audioPlayer.setAudioSource(source, initialIndex: _queueIndex);
      await audioPlayer.play();
    } catch (error) {
      if (!mounted) return;
      setState(() => playing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível tocar essa faixa: $error')),
      );
    }
  }


  Future<void> _openGuessSong() async {
    await audioPlayer.stop();
    if (!mounted) return;
    setState(() {
      currentAudiusTrack = null;
      playing = false;
    });
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => GuessSongGame(player: audioPlayer, service: AudiusService()),
    ));
    if (!mounted) return;
    await audioPlayer.stop();
    setState(() {
      currentAudiusTrack = null;
      playing = false;
    });
  }

  Future<void> _openMemoryGame() async {
    await audioPlayer.pause();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MemoryGame()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final page = [
      HomePage(onPlay: playTrack, onNavigate: (i) => setState(() => selected = i)),
      ExplorePage(
        searchQuery: _searchRequest,
        searchRequestId: _searchRequestId,
        onQueue: (queue) => _playQueue = queue,
        onPlay: (track) { _rememberTrack(track); playAudiusTrack(track); },
        isFavorite: (track) => favoriteIds.contains(track.id),
        ratingFor: (track) => ratings[track.id] ?? 0,
        onFavorite: _toggleFavorite,
        onRate: _rateTrack,
        onAddToPlaylist: _addToPlaylist,
        onDownload: _downloadTrack,
        isDownloading: (track) => downloadingIds.contains(track.id),
      ),
      const RoomsPage(),
      GamesPage(onGuessSong: _openGuessSong, onMemoryGame: _openMemoryGame),
      LibraryPage(
        onPlay: playTrack,
        favoriteTracks: favoriteIds.map((id) => savedTracks[id]).whereType<AudiusTrack>().toList(),
        playlists: playlists, savedTracks: savedTracks, ratings: ratings,
        onPlayAudius: playAudiusTrack, onRemoveFavorite: _toggleFavorite,
        onCreatePlaylist: _createPlaylist, onAddTrack: _addToPlaylist,
        downloadedTracks: downloadedPaths.keys.map((id) => savedTracks[id]).whereType<AudiusTrack>().toList(),
        onPlayDownloaded: _playDownloaded, onRemoveDownload: _removeDownload,
        onRemoveFromPlaylist: (p, track) { setState(() => p.trackIds.remove(track.id)); _saveLibrary(); },
      ),
      const CardsPage(),
    ][selected];

    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          if (wide) _sidebar(),
          Expanded(child: Column(children: [
            _topBar(),
            Expanded(child: page),
            _playerBar(),
          ])),
        ]),
      ),
      bottomNavigationBar: wide ? null : NavigationBar(
        backgroundColor: panel,
        indicatorColor: purple.withValues(alpha: .22),
        selectedIndex: selected,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.explore_rounded), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.headphones_rounded), label: 'Salas'),
          NavigationDestination(icon: Icon(Icons.sports_esports_rounded), label: 'Jogos'),
          NavigationDestination(icon: Icon(Icons.library_music_rounded), label: 'Biblioteca'),
          NavigationDestination(icon: Icon(Icons.style_rounded), label: 'Cartas'),
        ],
      ),
    );
  }

  Widget _sidebar() => Container(
    width: 224, color: const Color(0xFF0D0E16),
    padding: const EdgeInsets.fromLTRB(18, 22, 14, 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Brand(),
      const SizedBox(height: 42),
      const Text('MENU', style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      for (int i = 0; i < pages.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => setState(() => selected = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
              decoration: BoxDecoration(
                color: selected == i ? purple.withValues(alpha: .17) : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(children: [
                Icon([Icons.home_rounded, Icons.explore_rounded, Icons.headphones_rounded, Icons.sports_esports_rounded, Icons.library_music_rounded, Icons.style_rounded][i],
                  color: selected == i ? neon : muted, size: 19),
                const SizedBox(width: 12),
                Text(pages[i], style: TextStyle(color: selected == i ? Colors.white : muted, fontWeight: selected == i ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ),
        ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .06))),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.bolt_rounded, color: neon),
          SizedBox(height: 8),
          Text('Sua música. Sua galera.', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Descubra, jogue e escute junto.', style: TextStyle(color: muted, fontSize: 11)),
        ]),
      ),
    ]),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
    child: Row(children: [
      if (MediaQuery.sizeOf(context).width < 850) const Brand(compact: true)
      else Text(pages[selected], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const Spacer(),
      Container(
        width: MediaQuery.sizeOf(context).width > 520 ? 230 : 42,
        height: 40,
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(13)),
        child: MediaQuery.sizeOf(context).width > 520
          ? TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: _submitSearch,
              decoration: const InputDecoration(
                hintText: 'Buscar músicas, artistas...',
                hintStyle: TextStyle(color: muted, fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, size: 19, color: muted),
                border: InputBorder.none, contentPadding: EdgeInsets.only(top: 10),
              ),
            )
          : IconButton(
              tooltip: 'Buscar',
              onPressed: () => _openSearch(context),
              icon: const Icon(Icons.search_rounded, color: muted),
            ),
      ),
      const SizedBox(width: 10),
      InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: panel,
            title: const Text('Perfil COBRASONG'),
            content: const Text('Você está usando a versão de demonstração. Login e conta serão adicionados em uma próxima atualização.'),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar'))],
          ),
        ),
        child: CircleAvatar(backgroundColor: purple.withValues(alpha: .2), child: const Icon(Icons.person_rounded, color: neon)),
      ),
    ]),
  );

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      selected = 1;
      _searchRequest = query;
      _searchRequestId++;
    });
  }

  void _openSearch(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Buscar no COBRASONG'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Digite o nome de uma faixa ou artista'),
          onSubmitted: (value) {
            Navigator.pop(dialogContext);
            _submitSearch(value);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final value = controller.text.trim();
            Navigator.pop(dialogContext);
            _submitSearch(value);
          }, child: const Text('Buscar')),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _cycleRepeatMode() async {
    final next = (_repeatModeIndex + 1) % 3;
    final mode = switch (next) {
      1 => LoopMode.all,
      2 => LoopMode.one,
      _ => LoopMode.off,
    };
    await audioPlayer.setLoopMode(mode);
    if (mounted) setState(() => _repeatModeIndex = next);
  }

  Future<void> _skipNext() async {
    if (_playQueue.isEmpty) return;
    if (_queueIndex >= _playQueue.length - 1) {
      if (_repeatModeIndex == 1 && _playQueue.length > 1) {
        await audioPlayer.seek(Duration.zero, index: 0);
      }
      return;
    }
    await audioPlayer.seek(Duration.zero, index: _queueIndex + 1);
  }

  Future<void> _skipPrevious() async {
    if (_playQueue.isEmpty) return;
    if (audioPlayer.position.inSeconds > 3 || _queueIndex == 0) {
      await audioPlayer.seek(Duration.zero);
      return;
    }
    await audioPlayer.seek(Duration.zero, index: _queueIndex - 1);
  }

  Widget _playerBar() {
    final title = currentAudiusTrack?.title ?? tracks[currentTrack].title;
    final artist = currentAudiusTrack?.artist ?? tracks[currentTrack].artist;
    return Container(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF191A28), borderRadius: BorderRadius.circular(17), border: Border.all(color: purple.withValues(alpha: .25))),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(gradient: LinearGradient(colors: [tracks[currentTrack].color, purple]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.graphic_eq_rounded, color: Colors.white)),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10)),
      ])),
      IconButton(
        tooltip: _repeatModeIndex == 0
            ? 'Repetição desligada'
            : _repeatModeIndex == 1
                ? 'Repetir playlist'
                : 'Repetir música',
        onPressed: _cycleRepeatMode,
        icon: Icon(
          _repeatModeIndex == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded,
          color: _repeatModeIndex == 0 ? muted : neon,
        ),
      ),
      IconButton(
        onPressed: () async {
          if (currentAudiusTrack != null) {
            if (playing) {
              await audioPlayer.pause();
            } else {
              await audioPlayer.play();
            }
          }
          if (mounted) setState(() => playing = !playing);
        },
        icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: neon, size: 34),
      ),
      IconButton(
        tooltip: 'Música anterior',
        onPressed: currentAudiusTrack == null
            ? () { audioPlayer.stop(); setState(() { currentTrack = (currentTrack - 1 + tracks.length) % tracks.length; playing = true; }); }
            : _skipPrevious,
        icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
      ),
      IconButton(
        tooltip: 'Próxima música',
        onPressed: currentAudiusTrack == null
            ? () { audioPlayer.stop(); setState(() { currentTrack = (currentTrack + 1) % tracks.length; playing = true; }); }
            : _skipNext,
        icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
      ),
    ]),
  );
  }
}

class Brand extends StatelessWidget {
  final bool compact;
  const Brand({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 34, height: 34, decoration: BoxDecoration(gradient: const LinearGradient(colors: [purple, Color(0xFF5D36B8)]), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.graphic_eq_rounded, color: neon, size: 21)),
    const SizedBox(width: 9),
    const Text('COBRA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 17)),
    if (!compact) const Text('SONG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 17, color: neon)),
  ]);
}

class HomePage extends StatelessWidget {
  final ValueChanged<int> onPlay;
  final ValueChanged<int> onNavigate;
  const HomePage({super.key, required this.onPlay, required this.onNavigate});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF35205F), Color(0xFF171426), Color(0xFF10251F)]),
          border: Border.all(color: purple.withValues(alpha: .3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SINTA O SOM.\nCONECTE A GALERA.', style: TextStyle(fontSize: 25, height: 1.12, fontWeight: FontWeight.w900, letterSpacing: -.5)),
          const SizedBox(height: 10),
          const Text('Música, amigos e diversão no mesmo lugar.', style: TextStyle(color: Color(0xFFD0C9E2), fontSize: 12)),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(onPressed: () => onNavigate(1), icon: const Icon(Icons.explore_rounded, size: 17), label: const Text('Explorar'), style: FilledButton.styleFrom(backgroundColor: neon, foregroundColor: bg)),
            OutlinedButton.icon(onPressed: () => onNavigate(2), icon: const Icon(Icons.headphones_rounded, size: 17), label: const Text('Entrar numa sala'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: .25)))),
          ]),
        ]),
      ),
      const SizedBox(height: 27),
      const SectionTitle('Tocando no radar', subtitle: 'Faixas de demonstração para testar o player'),
      const SizedBox(height: 12),
      SizedBox(height: 155, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(width: 132, child: InkWell(
          onTap: () => onPlay(i),
          borderRadius: BorderRadius.circular(17),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Container(width: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(colors: [tracks[i].color, const Color(0xFF171521)]), borderRadius: BorderRadius.circular(16)), child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 42, color: Colors.white)))),
            const SizedBox(height: 8),
            Text(tracks[i].title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(tracks[i].artist, style: const TextStyle(color: muted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        )),
      )),
      const SizedBox(height: 26),
      const SectionTitle('Encontre sua vibe', subtitle: 'Entre em uma experiência'),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.65,
        children: [
          FeatureTile(icon: Icons.people_alt_rounded, title: 'Salas ao vivo', detail: 'Escute em sincronia', color: purple, onTap: () => onNavigate(2)),
          FeatureTile(icon: Icons.quiz_rounded, title: 'Quiz musical', detail: 'Teste seus ouvidos', color: neon, onTap: () => onNavigate(3)),
          FeatureTile(icon: Icons.favorite_rounded, title: 'Favoritas', detail: 'Sua coleção', color: const Color(0xFFFF6D9B), onTap: () => onNavigate(4)),
          FeatureTile(icon: Icons.auto_awesome_rounded, title: 'Descobertas', detail: 'Novas vibes', color: const Color(0xFF51D9C2), onTap: () => onNavigate(1)),
          FeatureTile(icon: Icons.style_rounded, title: 'COBRA CARDS', detail: 'Monte sua coleção', color: const Color(0xFFFFC857), onTap: () => onNavigate(5)),
        ],
      ),
    ],
  );
}

class ExplorePage extends StatefulWidget {
  final ValueChanged<AudiusTrack> onPlay;
  final ValueChanged<List<AudiusTrack>> onQueue;
  final String? searchQuery;
  final int searchRequestId;
  final bool Function(AudiusTrack) isFavorite;
  final int Function(AudiusTrack) ratingFor;
  final ValueChanged<AudiusTrack> onFavorite, onRate, onAddToPlaylist, onDownload;
  final bool Function(AudiusTrack) isDownloading;
  const ExplorePage({super.key, required this.onPlay, required this.onQueue, this.searchQuery, this.searchRequestId = 0, required this.isFavorite, required this.ratingFor, required this.onFavorite, required this.onRate, required this.onAddToPlaylist, required this.onDownload, required this.isDownloading});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final controller = TextEditingController();
  final service = AudiusService();
  String selectedGenre = 'Todos';
  static const Map<String, String> genres = {
    'Todos': 'music', 'Funk': 'Brazilian funk', 'Trap': 'trap',
    'Phonk': 'phonk', 'Rap / Hip-hop': 'hip hop rap', 'Pop': 'pop music',
    'Eletrônica': 'electronic dance music', 'Rock': 'rock music',
    'Sertanejo': 'sertanejo', 'Gospel': 'gospel', 'Lo-fi': 'lofi beats',
    'K-pop': 'k-pop', 'Reggae': 'reggae', 'Jazz': 'jazz',
    'Clássica': 'classical music', 'Forró': 'forro', 'Pagode': 'pagode',
    'MPB': 'musica popular brasileira', 'Indie': 'indie music',
    'Metal': 'metal', 'Samba': 'samba', 'Dance': 'dance music',
  };

  Future<void> _searchGenre(String label, String query) async {
    setState(() {
      selectedGenre = label;
      controller.text = query;
    });
    await _search();
  }
  List<AudiusTrack> results = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  int offset = 0;
  String? error;
  bool searched = false;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.searchQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      controller.text = initialQuery;
      _search();
    } else {
      _loadTrending();
    }
  }

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchRequestId != oldWidget.searchRequestId) {
      controller.text = widget.searchQuery ?? '';
      selectedGenre = 'Todos';
      _search();
    }
  }

  Future<void> _loadTrending() async {
    setState(() {
      loading = true;
      loadingMore = false;
      hasMore = true;
      offset = 0;
      error = null;
      searched = true;
      results = [];
    });
    try {
      final catalogs = await Future.wait<List<AudiusTrack>>([
        service.trending(), ITunesCatalogService().search('hits brasileiros'),
      ].map((future) => future.catchError((_) => <AudiusTrack>[])));
      if (!mounted) return;
      final found = [...catalogs[0], ...catalogs[1]];
      setState(() {
        results = found;
        offset = catalogs[0].length;
        hasMore = catalogs[0].length == 20;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Não consegui carregar as músicas em alta. Tente novamente.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      loading = true;
      loadingMore = false;
      hasMore = true;
      offset = 0;
      error = null;
      searched = true;
      results = [];
    });
    try {
      final catalogs = await Future.wait<List<AudiusTrack>>([
        service.search(query), ITunesCatalogService().search(query),
      ].map((future) => future.catchError((_) => <AudiusTrack>[])));
      if (!mounted) return;
      final found = [...catalogs[0], ...catalogs[1]];
      setState(() {
        results = found;
        offset = catalogs[0].length;
        hasMore = catalogs[0].length == 20;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Não consegui carregar o catálogo. Confira sua internet e tente novamente.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    setState(() {
      loadingMore = true;
      error = null;
    });
    try {
      final query = controller.text.trim();
      final found = query.isEmpty
          ? await service.trending(offset: offset)
          : await service.search(query, offset: offset);
      if (!mounted) return;
      final knownIds = results.map((track) => track.id).toSet();
      final newTracks = found.where((track) => !knownIds.contains(track.id)).toList();
      setState(() {
        results = [...results, ...newTracks];
        offset += found.length;
        hasMore = found.length == 20 && newTracks.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Não consegui carregar mais músicas. Tente novamente.');
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  String _time(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const SectionTitle('Explore músicas', subtitle: 'Busque artistas ou descubra vários estilos no catálogo aberto do Audius'),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: 'Nome da música ou artista',
            filled: true,
            fillColor: panel,
            prefixIcon: Icon(Icons.search_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
          ),
        )),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: loading ? null : _search,
          style: FilledButton.styleFrom(backgroundColor: neon, foregroundColor: bg, padding: const EdgeInsets.all(16)),
          child: const Icon(Icons.search_rounded),
        ),
      ]),
      const SizedBox(height: 16),
      const Text('Explore por estilo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 9),
      Wrap(
        spacing: 7, runSpacing: 7,
        children: [
          for (final genre in genres.entries)
            ChoiceChip(
              label: Text(genre.key),
              selected: selectedGenre == genre.key,
              onSelected: loading ? null : (_) => _searchGenre(genre.key, genre.value),
              selectedColor: purple.withValues(alpha: .32),
              backgroundColor: panel,
              side: BorderSide(color: selectedGenre == genre.key ? purple : Colors.white10),
              labelStyle: TextStyle(color: selectedGenre == genre.key ? Colors.white : muted, fontSize: 11),
            ),
        ],
      ),
      const SizedBox(height: 18),
      if (loading) const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: neon),
      )),
      if (error != null) InfoPanel(icon: Icons.wifi_off_rounded, title: 'Busca indisponível', text: error!),
      if (!loading && error == null && searched && results.isEmpty)
        const InfoPanel(icon: Icons.search_off_rounded, title: 'Nenhuma faixa encontrada', text: 'Tente outro nome de música ou artista.'),
      if (!loading && error == null && results.isNotEmpty && controller.text.trim().isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('🔥 Em alta nesta semana • novas faixas para descobrir', style: TextStyle(color: neon, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      for (final track in results)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 5),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.artwork == null
                ? Container(width: 48, height: 48, color: panel, child: const Icon(Icons.music_note_rounded, color: neon))
                : Image.network(track.artwork!, width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: panel, child: const Icon(Icons.music_note_rounded, color: neon))),
          ),
          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('${track.artist} • ${track.source == 'Audius' ? _time(track.duration) : 'prévia de 30s • iTunes'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11)),
          trailing: PopupMenuButton<String>(
            color: panel,
            onSelected: (action) {
              if (action == 'play') { widget.onQueue(results); widget.onPlay(track); }
              if (action == 'favorite') widget.onFavorite(track);
              if (action == 'rate') widget.onRate(track);
              if (action == 'playlist') widget.onAddToPlaylist(track);
              if (action == 'download') widget.onDownload(track);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'play', child: Text('Tocar')),
              PopupMenuItem(value: 'favorite', child: Text(widget.isFavorite(track) ? 'Remover dos favoritos' : 'Favoritar')),
              PopupMenuItem(value: 'rate', child: Text('Avaliar • ${widget.ratingFor(track)}/5')),
              const PopupMenuItem(value: 'playlist', child: Text('Adicionar à playlist')),
              if (track.downloadable) PopupMenuItem(value: 'download', child: Text(widget.isDownloading(track) ? 'Baixando...' : 'Baixar para ouvir offline')),
            ],
            icon: const Icon(Icons.more_vert_rounded, color: neon),
          ),
          onTap: () { widget.onQueue(results); widget.onPlay(track); },
        ),
      if (results.isNotEmpty && hasMore)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: OutlinedButton.icon(
              onPressed: loadingMore ? null : _loadMore,
              icon: loadingMore
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.expand_more_rounded),
              label: Text(loadingMore ? 'Carregando...' : 'Carregar mais músicas'),
            ),
          ),
        ),
      if (results.isNotEmpty && !hasMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: Text('Você chegou ao fim destes resultados.', style: TextStyle(color: muted, fontSize: 11))),
        ),
      const SizedBox(height: 12),
      const Text('Catálogos: Audius (faixas completas conforme disponibilidade) e iTunes (prévia de 30 segundos). Direitos pertencem aos respectivos criadores.', style: TextStyle(color: muted, fontSize: 10)),
    ],
  );
}

class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const SectionTitle('Salas musicais', subtitle: 'A ideia é ouvir junto, mesmo cada um estando em uma cidade'),
    const SizedBox(height: 15),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.headphones_rounded, color: neon, size: 32),
      SizedBox(height: 12),
      Text('Sua próxima sessão começa aqui', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      SizedBox(height: 7),
      Text('Salas sincronizadas, convites e chat estão no planejamento. Esta tela é uma prévia visual; a conexão em tempo real ainda será implementada.', style: TextStyle(color: muted, height: 1.5, fontSize: 12)),
    ])),
    const SizedBox(height: 14),
    FilledButton.icon(
      onPressed: () => _showFeatureNotice(context, 'Criar uma sala'),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Criar uma sala'),
      style: FilledButton.styleFrom(backgroundColor: neon, foregroundColor: bg),
    ),
  ]);
}

void _showFeatureNotice(BuildContext context, String feature) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: panel,
      title: Text(feature),
      content: const Text('Esse recurso ainda está em desenvolvimento. O botão agora responde ao toque, e o jogo será ativado em uma próxima versão.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Entendi'))],
    ),
  );
}


class GamesPage extends StatelessWidget {
  const GamesPage({super.key, required this.onGuessSong, required this.onMemoryGame});
  final VoidCallback onGuessSong;
  final VoidCallback onMemoryGame;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const SectionTitle('Arena COBRA', subtitle: 'Mini games para competir com a galera'),
    const SizedBox(height: 15),
    FeatureTile(icon: Icons.quiz_rounded, title: 'Adivinhe a música', detail: 'Descubra pelo trecho de áudio', color: purple, tall: true, onTap: onGuessSong),
    const SizedBox(height: 10),
    FeatureTile(icon: Icons.memory_rounded, title: 'Jogo da memória', detail: 'Encontre os pares musicais', color: const Color(0xFF51D9C2), tall: true, onTap: onMemoryGame),
    const SizedBox(height: 10),
    FeatureTile(icon: Icons.bolt_rounded, title: 'Batalha musical', detail: 'Escolha a melhor vibe', color: neon, tall: true, onTap: () => _showFeatureNotice(context, 'Batalha musical')),
    const SizedBox(height: 10),
    FeatureTile(icon: Icons.music_note_rounded, title: 'Desafio de ritmo', detail: 'Entre no compasso', color: const Color(0xFF51D9C2), tall: true, onTap: () => _showFeatureNotice(context, 'Desafio de ritmo')),
    const SizedBox(height: 14),
    const InfoPanel(icon: Icons.emoji_events_rounded, title: 'XP, níveis e conquistas', text: 'Os dois primeiros jogos já podem ser jogados. XP e ranking ficam para uma próxima etapa.'),
  ]);
}

class GuessSongGame extends StatefulWidget {
  const GuessSongGame({super.key, required this.player, required this.service});
  final AudioPlayer player;
  final AudiusService service;

  @override
  State<GuessSongGame> createState() => _GuessSongGameState();
}

class _GuessSongGameState extends State<GuessSongGame> {
  static const int _roundCount = 5;
  static const int _clipSeconds = 10;
  final Random _random = Random();
  final List<AudiusTrack> _pool = [];
  List<AudiusTrack> _rounds = [];
  List<AudiusTrack> _options = [];
  int _round = 0;
  int _score = 0;
  bool _loading = true;
  bool _answered = false;
  bool _audioFailed = false;
  String? _error;
  AudiusTrack? _picked;
  Timer? _cutTimer;

  bool get _finished => !_loading && _error == null && _round >= _rounds.length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cutTimer?.cancel();
    unawaited(widget.player.stop());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _round = 0;
      _score = 0;
    });
    try {
      final found = await widget.service.trending();
      if (found.length < 4) throw Exception('Poucas faixas disponíveis');
      _pool
        ..clear()
        ..addAll(found);
      _pool.shuffle(_random);
      _rounds = _pool.take(min(_roundCount, _pool.length)).toList();
      await _startRound();
    } catch (_) {
      _error = 'Não consegui carregar músicas para o jogo. Confira a internet e tente novamente.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startRound() async {
    if (_round >= _rounds.length) return;
    final correct = _rounds[_round];
    final others = _pool.where((track) => track.id != correct.id).toList()..shuffle(_random);
    _options = [correct, ...others.take(3)]..shuffle(_random);
    _answered = false;
    _picked = null;
    _audioFailed = false;
    _cutTimer?.cancel();
    try {
      await widget.player.setAudioSource(AudioSource.uri(
        Uri.parse(widget.service.streamUrl(correct.id)),
        tag: MediaItem(id: 'quiz-\${correct.id}', title: 'Adivinhe a música', artist: 'COBRASONG'),
      ));
      unawaited(widget.player.play());
      _cutTimer = Timer(const Duration(seconds: _clipSeconds), () => unawaited(widget.player.pause()));
    } catch (_) {
      _audioFailed = true;
    }
    if (mounted) setState(() {});
  }

  Future<void> _replay() async {
    _cutTimer?.cancel();
    try {
      await widget.player.seek(Duration.zero);
      unawaited(widget.player.play());
      _cutTimer = Timer(const Duration(seconds: _clipSeconds), () => unawaited(widget.player.pause()));
    } catch (_) {
      if (mounted) setState(() => _audioFailed = true);
    }
  }

  void _answer(AudiusTrack track) {
    if (_answered) return;
    _cutTimer?.cancel();
    unawaited(widget.player.pause());
    setState(() {
      _answered = true;
      _picked = track;
      if (track.id == _rounds[_round].id) _score++;
    });
  }

  Future<void> _next() async {
    setState(() => _round++);
    if (_round < _rounds.length) {
      await _startRound();
    } else {
      await widget.player.stop();
    }
  }

  Color _optionColor(AudiusTrack track) {
    if (!_answered) return panel;
    if (track.id == _rounds[_round].id) return neon.withValues(alpha: .24);
    if (track.id == _picked?.id) return Colors.redAccent.withValues(alpha: .24);
    return panel;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(backgroundColor: bg, foregroundColor: Colors.white, title: const Text('Adivinhe a Música')),
    body: Padding(padding: const EdgeInsets.all(18), child: _body()),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: neon));
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        const SizedBox(height: 14),
        FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
      ]));
    }
    if (_finished) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.emoji_events_rounded, color: neon, size: 64),
        const SizedBox(height: 12),
        Text('Você acertou $_score de \${_rounds.length}!', style: const TextStyle(color: neon, fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        FilledButton(onPressed: _load, child: const Text('Jogar novamente')),
      ]));
    }
    final correct = _rounds[_round];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Rodada \${_round + 1} de \${_rounds.length}  •  Pontos: $_score', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: purple.withValues(alpha: .35))),
        child: Column(children: [
          const Icon(Icons.headphones_rounded, color: neon, size: 58),
          const SizedBox(height: 8),
          Text(_audioFailed ? 'Não foi possível tocar o trecho.' : 'Ouça o trecho e escolha a faixa correta.', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _replay, icon: const Icon(Icons.replay_rounded), label: const Text('Ouvir novamente')),
          const Text('O trecho toca por até 10 segundos.', style: TextStyle(color: muted, fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 18),
      for (final track in _options)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Material(
            color: _optionColor(track),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: _answered ? null : () => _answer(track),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11)),
                  ])),
                  if (_answered && track.id == correct.id) const Icon(Icons.check_circle_rounded, color: neon),
                  if (_answered && track.id == _picked?.id && track.id != correct.id) const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                ]),
              ),
            ),
          ),
        ),
      const Spacer(),
      if (_answered) FilledButton(onPressed: _next, child: Text(_round + 1 == _rounds.length ? 'Ver resultado' : 'Próxima rodada')),
    ]);
  }
}

class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});
  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  static const List<String> _symbols = ['🐍', '🎵', '🎧', '🎸', '🥁', '🎹', '🎤', '🎺'];
  late List<String> _cards;
  late List<bool> _revealed;
  late List<bool> _matched;
  int? _first;
  bool _busy = false;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _cards = [..._symbols, ..._symbols]..shuffle(Random());
    _revealed = List<bool>.filled(_cards.length, false);
    _matched = List<bool>.filled(_cards.length, false);
    _first = null;
    _busy = false;
    _moves = 0;
  }

  bool get _won => _matched.every((matched) => matched);

  Future<void> _tap(int index) async {
    if (_busy || _revealed[index] || _matched[index]) return;
    setState(() => _revealed[index] = true);
    if (_first == null) {
      _first = index;
      return;
    }
    final first = _first!;
    _first = null;
    if (_cards[first] == _cards[index]) {
      setState(() {
        _matched[first] = true;
        _matched[index] = true;
        _moves++;
      });
    } else {
      _busy = true;
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      setState(() {
        _revealed[first] = false;
        _revealed[index] = false;
        _moves++;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(backgroundColor: bg, foregroundColor: Colors.white, title: const Text('Jogo da Memória')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text(_won ? 'Você venceu em $_moves jogadas!' : 'Jogadas: $_moves', style: const TextStyle(color: neon, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(child: GridView.builder(
          itemCount: _cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 9, crossAxisSpacing: 9),
          itemBuilder: (context, index) {
            final show = _revealed[index] || _matched[index];
            return GestureDetector(
              onTap: () => _tap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _matched[index] ? neon.withValues(alpha: .22) : (show ? panel : purple),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _matched[index] ? neon : purple, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(show ? _cards[index] : '?', style: const TextStyle(fontSize: 30)),
              ),
            );
          },
        )),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => setState(_newGame), icon: const Icon(Icons.refresh_rounded), label: const Text('Novo jogo')),
      ]),
    ),
  );
}


class LibraryPage extends StatelessWidget {
  final ValueChanged<int> onPlay;
  final List<AudiusTrack> favoriteTracks;
  final List<MusicPlaylist> playlists;
  final Map<String, AudiusTrack> savedTracks;
  final Map<String, int> ratings;
  final List<AudiusTrack> downloadedTracks;
  final ValueChanged<AudiusTrack> onPlayDownloaded, onRemoveDownload;
  final ValueChanged<AudiusTrack> onPlayAudius, onRemoveFavorite, onAddTrack;
  final VoidCallback onCreatePlaylist;
  final void Function(MusicPlaylist, AudiusTrack) onRemoveFromPlaylist;
  const LibraryPage({super.key, required this.onPlay, required this.favoriteTracks, required this.playlists, required this.savedTracks, required this.ratings, required this.downloadedTracks, required this.onPlayDownloaded, required this.onRemoveDownload, required this.onPlayAudius, required this.onRemoveFavorite, required this.onCreatePlaylist, required this.onAddTrack, required this.onRemoveFromPlaylist});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const SectionTitle('Sua biblioteca', subtitle: 'Favoritas, avaliações e playlists salvas neste aparelho'),
    const SizedBox(height: 16),
    Row(children: [
      const Expanded(child: Text('Suas favoritas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      Text('${favoriteTracks.length} músicas', style: const TextStyle(color: neon, fontSize: 11)),
    ]),
    if (favoriteTracks.isEmpty) const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: InfoPanel(icon: Icons.favorite_border_rounded, title: 'Ainda sem favoritas', text: 'Na aba Explorar, abra o menu de uma música e escolha Favoritar.'),
    ),
    for (final track in favoriteTracks) ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.music_note_rounded, color: neon),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${track.artist} • ${ratings[track.id] ?? 0}/5 estrelas', style: const TextStyle(color: muted, fontSize: 11)),
      trailing: IconButton(icon: const Icon(Icons.favorite, color: Color(0xFFFF6D9B)), onPressed: () => onRemoveFavorite(track)),
      onTap: () => onPlayAudius(track),
    ),
    const SizedBox(height: 20),
    Row(children: [
      const Expanded(child: Text('Minhas playlists', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      IconButton(onPressed: onCreatePlaylist, icon: const Icon(Icons.add_circle_rounded, color: neon), tooltip: 'Criar playlist'),
    ]),
    if (playlists.isEmpty) const InfoPanel(icon: Icons.queue_music_rounded, title: 'Crie sua primeira playlist', text: 'Organize as músicas do seu jeito e encontre tudo aqui.'),
    for (final playlist in playlists) Card(
      color: panel,
      child: ExpansionTile(
        leading: const Icon(Icons.queue_music_rounded, color: neon),
        title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${playlist.trackIds.length} músicas'),
        children: [
          if (playlist.trackIds.isEmpty) const ListTile(title: Text('Playlist vazia', style: TextStyle(color: muted))),
          for (final id in playlist.trackIds)
            if (savedTracks[id] != null) ListTile(
              dense: true,
              title: Text(savedTracks[id]!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(savedTracks[id]!.artist, style: const TextStyle(color: muted, fontSize: 11)),
              leading: const Icon(Icons.music_note_rounded, color: purple),
              trailing: IconButton(tooltip: 'Remover da playlist', icon: const Icon(Icons.remove_circle_outline_rounded, color: muted), onPressed: () => onRemoveFromPlaylist(playlist, savedTracks[id]!)),
              onTap: () => onPlayAudius(savedTracks[id]!),
            ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    Row(children: [
      const Expanded(child: Text('Disponíveis offline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      Text('${downloadedTracks.length} músicas', style: const TextStyle(color: neon, fontSize: 11)),
    ]),
    if (downloadedTracks.isEmpty) const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: InfoPanel(icon: Icons.offline_pin_rounded, title: 'Nenhum download ainda', text: 'Em Explorar, abra o menu de uma faixa liberada pelo criador e escolha “Baixar para ouvir offline”.'),
    ),
    for (final track in downloadedTracks) ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.offline_pin_rounded, color: neon),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artist, style: const TextStyle(color: muted, fontSize: 11)),
      trailing: IconButton(tooltip: 'Apagar download', icon: const Icon(Icons.delete_outline_rounded, color: muted), onPressed: () => onRemoveDownload(track)),
      onTap: () => onPlayDownloaded(track),
    ),
    const SizedBox(height: 18),
    const Text('Sugestões para começar', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    for (int i = 0; i < tracks.length; i++) TrackTile(track: tracks[i], index: i, onTap: () => onPlay(i)),
  ]);
}


class CollectibleCard {
  final String name, subtitle, rarity;
  final IconData icon;
  final List<Color> colors;
  const CollectibleCard(this.name, this.subtitle, this.rarity, this.icon, this.colors);
}

const collectibleCards = [
  CollectibleCard('Ritmo Neon', 'A energia que acende a pista', 'LENDÁRIA', Icons.bolt_rounded, [Color(0xFF5C35A8), Color(0xFFB8FF45)]),
  CollectibleCard('DJ Cósmico', 'O mestre das batidas', 'ÉPICA', Icons.album_rounded, [Color(0xFF173D70), Color(0xFF51D9C2)]),
  CollectibleCard('Fênix do Som', 'Renasce em cada refrão', 'RARA', Icons.local_fire_department_rounded, [Color(0xFF8E315B), Color(0xFFFF9A55)]),
  CollectibleCard('Beat de Rua', 'O grave que move a cidade', 'COMUM', Icons.graphic_eq_rounded, [Color(0xFF34364D), Color(0xFF8C91A8)]),
];

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});
  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  String filter = 'Todas';
  final Set<String> favorites = {};

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'LENDÁRIA':
        return const Color(0xFFFFC857);
      case 'ÉPICA':
        return purple;
      case 'RARA':
        return const Color(0xFF51D9C2);
      default:
        return muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = collectibleCards.where((card) =>
      filter == 'Todas' || card.rarity == filter.toUpperCase()
    ).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF38205F), Color(0xFF171521), Color(0xFF342719)],
            ),
            border: Border.all(color: const Color(0xFFFFC857).withValues(alpha: .35)),
          ),
          child: const Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COBRA CARDS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                SizedBox(height: 6),
                Text('Sua coleção, seu estilo. Reúna cartas musicais exclusivas.', style: TextStyle(color: Color(0xFFD8D0E5), fontSize: 11, height: 1.4)),
              ],
            )),
            SizedBox(width: 10),
            Icon(Icons.style_rounded, size: 48, color: Color(0xFFFFC857)),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: SectionTitle('Minha coleção', subtitle: 'Cartas demonstrativas para conhecer o sistema')),
          Text('${collectibleCards.length} cartas', style: const TextStyle(color: neon, fontWeight: FontWeight.bold, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final option in ['Todas', 'Lendária', 'Épica', 'Rara', 'Comum'])
            ChoiceChip(
              label: Text(option),
              selected: filter == option,
              onSelected: (_) => setState(() => filter = option),
              selectedColor: purple.withValues(alpha: .35),
              backgroundColor: panel,
              labelStyle: TextStyle(color: filter == option ? Colors.white : muted, fontSize: 11),
              side: BorderSide(color: filter == option ? purple : Colors.white10),
            ),
        ]),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .72,
          ),
          itemBuilder: (context, index) {
            final card = visible[index];
            final isFavorite = favorites.contains(card.name);
            final rarityColor = _rarityColor(card.rarity);
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: rarityColor.withValues(alpha: .55)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: card.colors,
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Stack(children: [
                      Positioned(right: 8, top: 8, child: Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: .65), size: 17)),
                      Center(child: Icon(card.icon, size: 58, color: Colors.white)),
                      Positioned(left: 8, bottom: 8, child: Text(card.rarity, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))),
                    ]),
                  ),
                ),
                const SizedBox(height: 9),
                Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 3),
                Text(card.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 9, height: 1.25)),
                Row(children: [
                  Expanded(child: Text(card.rarity, style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.bold))),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: () => setState(() {
                      if (isFavorite) {
                        favorites.remove(card.name);
                      } else {
                        favorites.add(card.name);
                      }
                    }),
                    icon: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavorite ? const Color(0xFFFF6D9B) : muted, size: 18),
                  ),
                ]),
              ]),
            );
          },
        ),
        const SizedBox(height: 16),
        const InfoPanel(
          icon: Icons.collections_bookmark_rounded,
          title: 'Mais cartas chegando',
          text: 'Esta é a primeira prévia da coleção. Pacotes, missões, trocas e salvamento da coleção serão adicionados em etapas futuras.',
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
    if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: const TextStyle(color: muted, fontSize: 11))],
  ]);
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title, detail;
  final Color color;
  final VoidCallback? onTap;
  final bool tall;
  const FeatureTile({super.key, required this.icon, required this.title, required this.detail, required this.color, this.onTap, this.tall = false});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(17),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: color.withValues(alpha: .18))),
      child: Row(children: [
        Container(width: 39, height: 39, decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
        const SizedBox(width: 11),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 3),
          Text(detail, style: const TextStyle(color: muted, fontSize: 10)),
        ])),
        if (tall) const Icon(Icons.chevron_right_rounded, color: muted),
      ]),
    ),
  );
}

class TrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final VoidCallback onTap;
  const TrackTile({super.key, required this.track, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 3),
    leading: Container(width: 45, height: 45, decoration: BoxDecoration(gradient: LinearGradient(colors: [track.color, purple]), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.equalizer_rounded, color: Colors.white)),
    title: Text(track.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    subtitle: Text(track.artist, style: const TextStyle(color: muted, fontSize: 11)),
    trailing: IconButton(onPressed: onTap, icon: const Icon(Icons.play_circle_fill_rounded, color: neon, size: 29)),
    onTap: onTap,
  );
}

class InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const InfoPanel({super.key, required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withValues(alpha: .06))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: neon, size: 25),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 5),
        Text(text, style: const TextStyle(color: muted, height: 1.45, fontSize: 11)),
      ])),
    ]),
  );
}
