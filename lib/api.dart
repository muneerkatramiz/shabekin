import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

typedef Json = Map<String, dynamic>;

class Api {
  String? token;
  String lang = 'ar';
  void Function()? onUnauthorized;

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{'Accept': 'application/json', 'X-Shabek-Lang': lang};
    if (json) h['Content-Type'] = 'application/json';
    final t = token;
    if (t != null) {
      h['Authorization'] = 'Bearer $t';
      h['X-Shabek-Token'] = t;
    }
    return h;
  }

  Json _parse(http.Response r) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300 && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (r.statusCode == 401 && token != null) onUnauthorized?.call();
    var msg = lang == 'en' ? 'Something went wrong. Please try again.' : 'حدث خطأ، حاول مرة أخرى.';
    if (data is Map && data['message'] is String) msg = data['message'] as String;
    throw ApiException(msg, r.statusCode);
  }

  Future<Json> _call(Future<http.Response> Function() f) async {
    try {
      final r = await f().timeout(const Duration(seconds: 30));
      return _parse(r);
    } on SocketException {
      throw ApiException(lang == 'en' ? 'No internet connection.' : 'لا يوجد اتصال بالإنترنت.', 0);
    } on TimeoutException {
      throw ApiException(lang == 'en' ? 'The connection timed out.' : 'انتهت مهلة الاتصال.', 0);
    } on http.ClientException {
      throw ApiException(lang == 'en' ? 'No internet connection.' : 'لا يوجد اتصال بالإنترنت.', 0);
    }
  }

  Uri _u(String p) => Uri.parse('${AppConfig.apiBase}$p');
  Future<Json> get(String p) => _call(() => http.get(_u(p), headers: _headers(json: false)));
  Future<Json> post(String p, [Json? body]) =>
      _call(() => http.post(_u(p), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<Json> multipart(String p, Map<String, String> fields, Map<String, String> files) => _call(() async {
        final req = http.MultipartRequest('POST', _u(p));
        req.headers.addAll(_headers(json: false));
        req.fields.addAll(fields);
        for (final e in files.entries) {
          req.files.add(await http.MultipartFile.fromPath(e.key, e.value));
        }
        final s = await req.send();
        return http.Response.fromStream(s);
      });

  List<Json> _list(Json r, String k) =>
      ((r[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<Json> config() => get('/config');
  Future<Json> login(String e, String p) => post('/auth/login', {'email': e, 'password': p});
  Future<Json> register(Json b) => post('/auth/register', b);
  Future<void> forgot(String e) async {
    await post('/auth/forgot', {'email': e});
  }

  Future<Json> me() => get('/auth/me');
  Future<void> deleteAccount(String p) async {
    await post('/auth/delete', {'password': p});
  }

  Future<Json> createRequest(Json b) => post('/requests', b);
  Future<List<Json>> requests() async => _list(await get('/requests'), 'requests');
  Future<Json> request(int id) => get('/requests/$id');
  Future<void> cancelRequest(int id) async {
    await post('/requests/$id/cancel');
  }

  Future<void> acceptOffer(int id) async {
    await post('/offers/$id/accept');
  }

  Future<List<Json>> providerRequests() async => _list(await get('/provider/requests'), 'requests');
  Future<List<Json>> providerOffers() async => _list(await get('/provider/offers'), 'offers');
  Future<void> sendOffer(int reqId, String amount, String message) async {
    await post('/provider/requests/$reqId/offers', {'amount': amount, 'message': message});
  }

  Future<List<Json>> vehicles() async => _list(await get('/provider/vehicles'), 'vehicles');
  Future<void> addVehicle(Json b) async {
    await post('/provider/vehicles', b);
  }

  Future<Json> providerRegister(Map<String, String> fields, Map<String, String> files) =>
      multipart('/provider/register', fields, files);
}
