import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';

class AppState extends ChangeNotifier {
  final Api api = Api();
  static const _storage = FlutterSecureStorage();

  String lang = 'ar';
  Json? user;
  Json config = {};
  String? bootError;
  bool ready = false;
  int tab = 0;
  int dataVersion = 0;

  bool get loggedIn => user != null;
  bool get isProvider => user?['is_provider'] == true;
  String? get providerStatus => user?['provider_status'] as String?;
  bool get approvedProvider => isProvider && providerStatus == 'approved';
  List<Json> get services =>
      ((config['services'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  String get privacyUrl => (config['privacy_url'] as String?) ?? '';
  String get termsUrl => (config['terms_url'] as String?) ?? '';
  String get supportEmail => (config['support_email'] as String?) ?? '';
  Json? get notice => config['notice'] is Map ? Map<String, dynamic>.from(config['notice'] as Map) : null;
  List<Json> get pages =>
      ((config['pages'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  String localized(dynamic m) {
    if (m is Map) return (m[lang] ?? m['ar'] ?? '').toString();
    return (m ?? '').toString();
  }

  Future<void> init() async {
    api.onUnauthorized = () {
      _clear();
    };
    try {
      lang = (await _storage.read(key: 'lang')) ?? 'ar';
      api.lang = lang;
      api.token = await _storage.read(key: 'token');
      final cached = await _storage.read(key: 'user');
      if (api.token != null && cached != null) {
        user = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      }
    } catch (_) {}
    await loadConfig();
    ready = true;
    notifyListeners();
    if (api.token != null) {
      try {
        await refreshUser();
      } catch (_) {}
    }
  }

  /// Pulls the latest WordPress data (services, banner, pages, account status) and reloads open lists.
  Future<void> sync() async {
    if (!ready) return;
    await loadConfig();
    if (loggedIn) {
      try {
        await refreshUser();
      } catch (_) {}
    }
    bump();
  }

  Future<void> loadConfig() async {
    try {
      config = await api.config();
      bootError = null;
    } catch (e) {
      bootError = e is ApiException ? e.message : e.toString();
    }
    notifyListeners();
  }

  Future<void> setLang(String l) async {
    lang = l;
    api.lang = l;
    try {
      await _storage.write(key: 'lang', value: l);
    } catch (_) {}
    notifyListeners();
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void bump() {
    dataVersion++;
    notifyListeners();
  }

  Future<void> _setSession(Json res) async {
    api.token = res['token'] as String;
    user = Map<String, dynamic>.from(res['user'] as Map);
    try {
      await _storage.write(key: 'token', value: api.token);
      await _storage.write(key: 'user', value: jsonEncode(user));
    } catch (_) {}
    dataVersion++;
    notifyListeners();
  }

  Future<void> _clear() async {
    api.token = null;
    user = null;
    tab = 0;
    try {
      await _storage.delete(key: 'token');
      await _storage.delete(key: 'user');
    } catch (_) {}
    dataVersion++;
    notifyListeners();
  }

  Future<void> login(String email, String pass) async => _setSession(await api.login(email, pass));
  Future<void> register(Json body) async => _setSession(await api.register(body));
  Future<void> providerRegister(Map<String, String> f, Map<String, String> files) async =>
      _setSession(await api.providerRegister(f, files));
  Future<void> logout() => _clear();

  Future<void> deleteAccount(String pass) async {
    await api.deleteAccount(pass);
    await _clear();
  }

  Future<void> refreshUser() async {
    final r = await api.me();
    user = Map<String, dynamic>.from(r['user'] as Map);
    try {
      await _storage.write(key: 'user', value: jsonEncode(user));
    } catch (_) {}
    notifyListeners();
  }
}
