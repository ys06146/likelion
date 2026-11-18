import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

enum SessionStatus { authenticated, anonymous, unavailable }

class AuthService {
  static String get baseUrl => ApiClient.baseUrl;
  static String get googleClientId => ApiClient.googleClientId;
  static final sessionExpired = ValueNotifier<int>(0);
  static const _profileKeys = [
    'profile_full_name',
    'profile_age',
    'profile_gender',
    'profile_blood_type',
    'profile_smoker',
    'profile_alcohol',
  ];

  static Future<Map<String, dynamic>> _result(
    Future<Map<String, dynamic>> Function() operation,
  ) async {
    try {
      return {'success': true, 'data': await operation()};
    } on ApiException catch (e) {
      if (e.statusCode == 401) await logout(expired: true);
      return {
        'success': false,
        'message': e.message,
        'statusCode': e.statusCode,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to complete the request. Please try again.',
      };
    }
  }

  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String fullName,
  }) => _result(
    () => ApiClient.request(
      'POST',
      '/auth/signup',
      body: {
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
      },
    ),
  );

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _result(() async {
    final body = await ApiClient.request(
      'POST',
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    await _saveSession(body);
    return body;
  });

  static Future<Map<String, dynamic>> loginWithIdToken({
    required String idToken,
    String? email,
    String? displayName,
  }) => _result(() async {
    final body = await ApiClient.request(
      'POST',
      '/auth/google/mobile',
      body: {'id_token': idToken},
    );
    await _saveSession(body);
    return body;
  });

  static Future<void> _saveSession(Map<String, dynamic> body) async {
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('The server did not return a valid session.');
    }
    final prefs = await SharedPreferences.getInstance();
    await _clearProfile(prefs);
    await prefs.setString('access_token', token);
    await prefs.setString(
      'cached_account_email',
      body['email']?.toString() ?? '',
    );
    final profile = body['profile'];
    if (profile is Map) {
      await persistServerProfileMap(Map<String, dynamic>.from(profile));
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required int? age,
    required String? gender,
    required String? bloodType,
    required bool smoker,
    required bool alcohol,
  }) => _result(() async {
    final token = await getToken();
    if (token == null) throw const ApiException('Please sign in again.', 401);
    final profile = <String, dynamic>{
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'blood_type': bloodType,
      'smoker': smoker,
      'alcohol': alcohol,
    };
    final response = await ApiClient.request(
      'PATCH',
      '/users/me',
      token: token,
      body: profile,
    );
    // Commit the local cache only after the server accepts the update.
    await persistServerProfileMap(profile);
    return response;
  });

  static Future<void> _clearProfile(SharedPreferences prefs) async {
    for (final key in _profileKeys) {
      await prefs.remove(key);
    }
  }

  static Future<void> persistServerProfileMap(
    Map<String, dynamic> profile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _clearProfile(prefs);
    for (final key in ['full_name', 'gender', 'blood_type']) {
      final value = profile[key];
      if (value is String && value.isNotEmpty) {
        await prefs.setString('profile_$key', value);
      }
    }
    if (profile['age'] is num) {
      await prefs.setInt('profile_age', (profile['age'] as num).toInt());
    }
    for (final key in ['smoker', 'alcohol']) {
      if (profile[key] is bool) {
        await prefs.setBool('profile_$key', profile[key] as bool);
      }
    }
  }

  static Future<SessionStatus> restoreSession() async {
    final token = await getToken();
    if (token == null) return SessionStatus.anonymous;
    try {
      final profile = await ApiClient.request('GET', '/users/me', token: token);
      await persistServerProfileMap(profile);
      return SessionStatus.authenticated;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await logout();
        return SessionStatus.anonymous;
      }
      return SessionStatus.unavailable;
    } catch (_) {
      return SessionStatus.unavailable;
    }
  }

  static Future<void> refreshProfileFromServer() async {
    final status = await restoreSession();
    if (status == SessionStatus.anonymous) sessionExpired.value++;
  }

  static Future<Map<String, dynamic>> getSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'full_name': prefs.getString('profile_full_name') ?? '',
      'age': prefs.getInt('profile_age'),
      'gender': prefs.getString('profile_gender'),
      'blood_type': prefs.getString('profile_blood_type'),
      'smoker': prefs.getBool('profile_smoker') ?? false,
      'alcohol': prefs.getBool('profile_alcohol') ?? false,
    };
  }

  static Future<String?> getToken() async {
    final token = (await SharedPreferences.getInstance()).getString(
      'access_token',
    );
    return token == null || token.isEmpty ? null : token;
  }

  static Future<void> logout({bool expired = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('token_type');
    await prefs.remove('cached_account_email');
    await _clearProfile(prefs);
    if (expired) sessionExpired.value++;
  }
}
