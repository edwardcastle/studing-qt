import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which lessons are finished and which songs have been practised.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs)
    : _lessons = (_prefs.getStringList(_lessonsKey) ?? const []).toSet(),
      _songs = (_prefs.getStringList(_songsKey) ?? const []).toSet();

  static const _lessonsKey = 'completed_lessons';
  static const _songsKey = 'practised_songs';

  static Future<ProgressStore> load() async =>
      ProgressStore._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  final Set<String> _lessons;
  final Set<String> _songs;

  bool isLessonDone(String id) => _lessons.contains(id);
  bool isSongPractised(String id) => _songs.contains(id);
  int get lessonsDone => _lessons.length;

  Future<void> completeLesson(String id) async {
    if (_lessons.add(id)) {
      notifyListeners();
      await _prefs.setStringList(_lessonsKey, _lessons.toList());
    }
  }

  Future<void> completeSong(String id) async {
    if (_songs.add(id)) {
      notifyListeners();
      await _prefs.setStringList(_songsKey, _songs.toList());
    }
  }

  Future<void> reset() async {
    _lessons.clear();
    _songs.clear();
    notifyListeners();
    await _prefs.remove(_lessonsKey);
    await _prefs.remove(_songsKey);
  }
}
