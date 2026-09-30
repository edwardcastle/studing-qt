import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocarina_quest/app.dart';
import 'package:ocarina_quest/audio/sound_player.dart';
import 'package:ocarina_quest/data/lessons.dart';
import 'package:ocarina_quest/data/notes.dart';
import 'package:ocarina_quest/data/songs.dart';
import 'package:ocarina_quest/models/hole.dart';
import 'package:ocarina_quest/screens/lesson_screen.dart';
import 'package:ocarina_quest/screens/song_player_screen.dart';
import 'package:ocarina_quest/state/app_scope.dart';
import 'package:ocarina_quest/state/progress_store.dart';
import 'package:ocarina_quest/widgets/ocarina_diagram.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProgressStore, SilentSoundPlayer)> _services() async {
  SharedPreferences.setMockInitialValues({});
  return (await ProgressStore.load(), SilentSoundPlayer());
}

Widget _wrap(ProgressStore progress, SoundPlayer player, Widget child) =>
    AppScope(
      progress: progress,
      player: player,
      child: MaterialApp(home: child),
    );

/// Taps the given holes on the (only) ocarina diagram on screen.
Future<void> _tapHoles(WidgetTester tester, Iterable<Hole> holes) async {
  final finder = find.byType(OcarinaDiagram);
  final topLeft = tester.getTopLeft(finder);
  final size = tester.getSize(finder);
  for (final hole in holes) {
    await tester.tapAt(topLeft + holeCenter(hole, size));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('home shows the learning path and navigates tabs', (
    tester,
  ) async {
    final (progress, player) = await _services();
    await tester.pumpWidget(
      OcarinaQuestApp(progress: progress, player: player),
    );

    expect(find.text('Your learning path'), findsOneWidget);
    expect(find.text(kLessons.first.title), findsOneWidget);

    await tester.tap(find.text('Chart'));
    await tester.pumpAndSettle();
    expect(find.text('Fingering chart'), findsOneWidget);

    await tester.tap(find.text('Songs').last);
    await tester.pumpAndSettle();
    expect(find.text('Hot Cross Buns'), findsOneWidget);
  });

  testWidgets('fingering quiz accepts the right holes and completes lesson', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final (progress, player) = await _services();
    final lesson = kLessons.firstWhere((l) => l.id == 'first_note');
    await tester.pumpWidget(
      _wrap(progress, player, LessonScreen(lesson: lesson)),
    );

    // Step 1: note intro, Next is enabled.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2: quiz; Finish stays disabled until the fingering is right.
    final finish = find.widgetWithText(FilledButton, 'Finish');
    expect(tester.widget<FilledButton>(finish).onPressed, isNull);

    await _tapHoles(tester, noteById('C').covered);
    expect(find.text('Correct!'), findsOneWidget);
    expect(player.played, ['C']);
    expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);

    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(progress.isLessonDone('first_note'), isTrue);
  });

  testWidgets('song player watch mode plays through the melody', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final (progress, player) = await _services();
    final song = songById('hot_cross_buns');
    await tester.pumpWidget(
      _wrap(progress, player, SongPlayerScreen(song: song)),
    );

    await tester.tap(find.text('Play'));
    // Long enough for the whole song at its default tempo.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(player.played, song.notes.map((n) => n.note!.id).toList());
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('song practice mode advances on correct fingerings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    final (progress, player) = await _services();
    final song = songById('hot_cross_buns');
    await tester.pumpWidget(
      _wrap(progress, player, SongPlayerScreen(song: song)),
    );
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();

    // First note is E: cover its holes.
    await _tapHoles(tester, noteById('E').covered);
    expect(player.played, ['E']);
  });
}
