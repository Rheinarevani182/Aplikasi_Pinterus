import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pin_model.dart';
import '../models/user_model.dart';

class ApiService {
  static const _tokenKey = 'pinterus_api_token';
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  String? _token;

  String get token => _token ?? '';

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  Future<void> loadStoredToken() async {
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString(_tokenKey);
  }

  Future<void> _storeToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = await preferences.setString(_tokenKey, token);
    if (!stored) {
      throw const ApiException('Sesi login tidak dapat disimpan.');
    }
    _token = token;
  }

  Future<void> clearStoredToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    _token = null;
  }

  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final body = await _sendJson('POST', '/auth/register', {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'password_confirmation': password,
    });

    await _storeToken(body['data']['token'] as String);
    return UserModel.fromJson(body['data']['user'] as Map<String, dynamic>);
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final body = await _sendJson('POST', '/auth/login', {
      'email': email,
      'password': password,
    });

    await _storeToken(body['data']['token'] as String);
    return UserModel.fromJson(body['data']['user'] as Map<String, dynamic>);
  }

  Future<UserModel> fetchCurrentUser() async {
    final body = await _sendJson('GET', '/me');
    return UserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _sendJson('POST', '/auth/logout');
    } finally {
      await clearStoredToken();
    }
  }

  Future<List<PinModel>> fetchPins() async {
    final body = await _sendJson('GET', '/pins');
    return _parsePins(body['data']);
  }

  Future<List<PinModel>> fetchSavedPins() async {
    final body = await _sendJson('GET', '/me/saved-pins');
    return _parsePins(body['data']);
  }

  Future<List<PinModel>> fetchUserPins(int userId) async {
    final body = await _sendJson('GET', '/users/$userId');
    return _parsePins(body['data']['pins']);
  }

  Future<Map<String, dynamic>> fetchProfile(int userId) async {
    final body = await _sendJson('GET', '/users/$userId');
    return body['data'] as Map<String, dynamic>;
  }

  Future<PinModel> createPin({
    required String title,
    required String description,
    required XFile imageFile,
    required String category,
    String? linkUrl,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/pins'));
    request.headers.addAll(_headers(includeContentType: false));
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['category'] = category;
    if (linkUrl?.isNotEmpty == true) {
      request.fields['link_url'] = linkUrl!;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await imageFile.readAsBytes(),
        filename: imageFile.name,
      ),
    );

    final response = await http.Response.fromStream(await request.send());
    final body = _decodeResponse(response);
    return PinModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<UserModel> updateProfile({
    required String name,
    required String username,
    required String bio,
    XFile? avatar,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/me'));
    request.headers.addAll(_headers(includeContentType: false));
    request.fields['_method'] = 'PATCH';
    request.fields['name'] = name;
    request.fields['username'] = username;
    request.fields['bio'] = bio;
    if (avatar != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          await avatar.readAsBytes(),
          filename: avatar.name,
        ),
      );
    }

    final response = await http.Response.fromStream(await request.send());
    final body = _decodeResponse(response);
    return UserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<UserModel> updateProfileVisibility({
    required UserModel user,
    required bool isPrivate,
  }) async {
    final body = await _sendJson('PATCH', '/me', {
      'name': user.name,
      'username': user.username,
      'bio': user.bio,
      'private_account': isPrivate,
    });
    return UserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _sendJson('PATCH', '/me/password', {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': newPassword,
    });
  }

  Future<List<Map<String, dynamic>>> fetchReports() async {
    final body = await _sendJson('GET', '/me/reports');
    final data = body['data'];
    if (data is! List<dynamic>) {
      throw const ApiException('Data laporan dari server tidak valid.');
    }
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> savePin(int pinId, {required bool save}) async {
    await _sendJson(save ? 'POST' : 'DELETE', '/pins/$pinId/save');
  }

  Future<void> deletePin(int pinId) async {
    await _sendJson('DELETE', '/pins/$pinId');
  }

  Future<void> reportPin(int pinId, String reason) async {
    await _sendJson('POST', '/pins/$pinId/report', {'reason': reason});
  }

  Future<bool> followUser(int userId, {required bool follow}) async {
    final body = await _sendJson(
      follow ? 'POST' : 'DELETE',
      '/users/$userId/follow',
    );
    return body['is_following'] as bool? ?? follow;
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = _headers();
    final encodedBody = data == null ? null : jsonEncode(data);

    final response = switch (method) {
      'GET' => await http.get(uri, headers: headers),
      'POST' => await http.post(uri, headers: headers, body: encodedBody),
      'PATCH' => await http.patch(uri, headers: headers, body: encodedBody),
      'DELETE' => await http.delete(uri, headers: headers, body: encodedBody),
      _ => throw ArgumentError.value(method, 'method', 'Metode tidak didukung'),
    };

    return _decodeResponse(response);
  }

  Map<String, String> _headers({bool includeContentType = true}) {
    return {
      'Accept': 'application/json',
      if (includeContentType) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('Server mengirim respons yang tidak valid.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Format respons dari server tidak valid.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = decoded['errors'];
      Object? firstError;
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstValue = errors.values.first;
        if (firstValue is List<dynamic> && firstValue.isNotEmpty) {
          firstError = firstValue.first;
        }
      }
      final message = firstError is String
          ? firstError
          : decoded['message'] as String? ?? 'Permintaan gagal.';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }

  List<PinModel> _parsePins(Object? data) {
    if (data is! List<dynamic>) {
      throw const ApiException('Data pin dari server tidak valid.');
    }

    return data
        .map((item) => PinModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String resolveImageUrl(String value) {
    final imageUri = Uri.tryParse(value);
    if (imageUri == null) {
      return value;
    }

    if (imageUri.host.isEmpty) {
      return Uri.parse(baseUrl).resolve(value).toString();
    }

    if (imageUri.host == 'localhost' || imageUri.host == '127.0.0.1') {
      final apiUri = Uri.parse(baseUrl);
      return imageUri
          .replace(
            scheme: apiUri.scheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
          )
          .toString();
    }

    return value;
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
