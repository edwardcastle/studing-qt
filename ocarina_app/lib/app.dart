import 'package:flutter/material.dart';

import 'audio/sound_player.dart';
import 'screens/chart_screen.dart';
import 'screens/free_play_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/songs_screen.dart';
import 'state/app_scope.dart';
import 'state/progress_store.dart';

class OcarinaQuestApp extends StatelessWidget {
  const OcarinaQuestApp({
    super.key,
    required this.progress,
    required this.player,
  });

  final ProgressStore progress;
  final SoundPlayer player;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFB5651D); // terracotta clay
    return AppScope(
      progress: progress,
      player: player,
      child: MaterialApp(
        title: 'Ocarina Quest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

/// Bottom navigation between the four main areas of the app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _pages = [
    LessonsScreen(),
    ChartScreen(),
    FreePlayScreen(),
    SongsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Chart'),
          NavigationDestination(icon: Icon(Icons.piano), label: 'Play'),
          NavigationDestination(
            icon: Icon(Icons.library_music),
            label: 'Songs',
          ),
        ],
      ),
    );
  }
}
