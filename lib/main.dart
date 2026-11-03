import 'package:flutter/material.dart';

void main() => runApp(const CobraSongApp());

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

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selected = 0;
  bool playing = false;
  int currentTrack = 0;
  final pages = const ['Início', 'Explorar', 'Salas', 'Jogos', 'Biblioteca', 'Cartas'];

  void playTrack(int index) => setState(() {
    currentTrack = index;
    playing = true;
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final page = [
      HomePage(onPlay: playTrack, onNavigate: (i) => setState(() => selected = i)),
      ExplorePage(onPlay: playTrack),
      const RoomsPage(),
      const GamesPage(),
      LibraryPage(onPlay: playTrack),
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
          ? const TextField(
              decoration: InputDecoration(
                hintText: 'Buscar músicas, artistas...',
                hintStyle: TextStyle(color: muted, fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, size: 19, color: muted),
                border: InputBorder.none, contentPadding: EdgeInsets.only(top: 10),
              ),
            )
          : const Icon(Icons.search_rounded, color: muted),
      ),
      const SizedBox(width: 10),
      CircleAvatar(backgroundColor: purple.withValues(alpha: .2), child: const Icon(Icons.person_rounded, color: neon)),
    ]),
  );

  Widget _playerBar() => Container(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF191A28), borderRadius: BorderRadius.circular(17), border: Border.all(color: purple.withValues(alpha: .25))),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(gradient: LinearGradient(colors: [tracks[currentTrack].color, purple]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.graphic_eq_rounded, color: Colors.white)),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tracks[currentTrack].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Text(tracks[currentTrack].artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10)),
      ])),
      IconButton(onPressed: () => setState(() => playing = !playing), icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: neon, size: 34)),
      IconButton(onPressed: () => setState(() { currentTrack = (currentTrack + 1) % tracks.length; playing = true; }), icon: const Icon(Icons.skip_next_rounded, color: Colors.white)),
    ]),
  );
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

class ExplorePage extends StatelessWidget {
  final ValueChanged<int> onPlay;
  const ExplorePage({super.key, required this.onPlay});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const SectionTitle('Explore sons novos', subtitle: 'Uma seleção de faixas fictícias para testar a experiência'),
    const SizedBox(height: 15),
    for (int i = 0; i < tracks.length; i++) TrackTile(track: tracks[i], index: i, onTap: () => onPlay(i)),
    const SizedBox(height: 18),
    const InfoPanel(icon: Icons.public_rounded, title: 'Catálogo em construção', text: 'As músicas reais serão adicionadas somente com arquivos próprios, domínio público ou licenças adequadas.'),
  ]);
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
    const InfoPanel(icon: Icons.add_circle_outline_rounded, title: 'Criar uma sala', text: 'Em breve: escolha um nome, convide seus amigos e controle a sessão em conjunto.'),
  ]);
}

class GamesPage extends StatelessWidget {
  const GamesPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: const [
    SectionTitle('Arena COBRA', subtitle: 'Mini games para competir com a galera'),
    SizedBox(height: 15),
    FeatureTile(icon: Icons.quiz_rounded, title: 'Adivinhe a música', detail: 'Descubra pelo trecho', color: purple, tall: true),
    SizedBox(height: 10),
    FeatureTile(icon: Icons.bolt_rounded, title: 'Batalha musical', detail: 'Escolha a melhor vibe', color: neon, tall: true),
    SizedBox(height: 10),
    FeatureTile(icon: Icons.music_note_rounded, title: 'Desafio de ritmo', detail: 'Entre no compasso', color: Color(0xFF51D9C2), tall: true),
    SizedBox(height: 14),
    InfoPanel(icon: Icons.emoji_events_rounded, title: 'XP, níveis e conquistas', text: 'Sistema de pontuação e ranking será conectado aos jogos nas próximas versões.'),
  ]);
}

class LibraryPage extends StatelessWidget {
  final ValueChanged<int> onPlay;
  const LibraryPage({super.key, required this.onPlay});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const SectionTitle('Sua biblioteca', subtitle: 'Tudo que você guardar fica por aqui'),
    const SizedBox(height: 15),
    const InfoPanel(icon: Icons.favorite_rounded, title: 'Suas favoritas', text: 'As faixas que você curtir vão aparecer nesta área.'),
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
