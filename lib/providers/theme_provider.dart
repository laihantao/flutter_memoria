import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeIdKey = 'active_theme_id';
const _kAnimationsKey = 'animations_enabled';

// ── Active theme ───────────────────────────────────────────────────────────────

class ActiveThemeNotifier extends Notifier<String> {
  @override
  String build() {
    _loadSaved();
    return 'warm_clay';
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kThemeIdKey);
    if (id != null && id != state) state = id;
  }

  Future<void> setTheme(String id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeIdKey, id);
  }
}

final activeThemeIdProvider = NotifierProvider<ActiveThemeNotifier, String>(
  ActiveThemeNotifier.new,
);

// ── Animations enabled ─────────────────────────────────────────────────────────

class AnimationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadSaved();
    return true;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool(_kAnimationsKey);
    if (val != null && val != state) state = val;
  }

  Future<void> setEnabled(bool val) async {
    state = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAnimationsKey, val);
  }
}

final animationsEnabledProvider = NotifierProvider<AnimationsEnabledNotifier, bool>(
  AnimationsEnabledNotifier.new,
);
