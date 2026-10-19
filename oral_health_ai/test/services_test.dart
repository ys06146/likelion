import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oral_health_ai/services/api_client.dart';
import 'package:oral_health_ai/services/auth_service.dart';
import 'package:oral_health_ai/services/scan_service.dart';
import 'package:oral_health_ai/services/google_oauth_validation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({
    'access_token': 'test-token', 'profile_full_name': 'Existing', 'profile_age': 29,
  }));
  test('Profile cache changes only after successful server update', () async {
    await http.runWithClient(() async {
      final result = await AuthService.updateProfile(fullName: 'New', age: 30, gender: null,
        bloodType: null, smoker: false, alcohol: false);
      expect(result['success'], false);
      expect((await AuthService.getSavedProfile())['full_name'], 'Existing');
    }, () => MockClient((r) async => http.Response('{"detail":"Unavailable"}', 503)));
    await http.runWithClient(() async {
      final result = await AuthService.updateProfile(fullName: 'New', age: null, gender: null,
        bloodType: null, smoker: false, alcohol: false);
      expect(result['success'], true);
      final profile = await AuthService.getSavedProfile();
      expect(profile['full_name'], 'New');
      expect(profile['age'], isNull);
    }, () => MockClient((r) async => http.Response('{"message":"Saved"}', 200)));
  });
  test('Unauthorized scan clears the expired session', () async {
    await http.runWithClient(() async {
      final response = await ScanService.getHistory();
      expect(response['statusCode'], 401);
      expect(await AuthService.getToken(), isNull);
    }, () => MockClient((r) async => http.Response('{"detail":"Expired"}', 401)));
  });
  test('Logout removes cached profile values', () async {
    await AuthService.logout();
    expect(await AuthService.getToken(), isNull);
    expect((await AuthService.getSavedProfile())['age'], isNull);
  });
  test('Upload keeps score precision and strips fabricated details', () async {
    await http.runWithClient(() async {
      final result = await ScanService.analyzeImage(XFile.fromData(Uint8List.fromList([1,2,3]), name: 'test.png'));
      expect(result['riskPercent'], 15.35);
      expect(result['details'], isEmpty);
    }, () => MockClient((r) async => http.Response(jsonEncode({
      'prob_percent': 15.35, 'level': 'Normal', 'details': {'gums':'Healthy','plaque':'Moderate'},
    }), 200)));
  });
  test('Oversize uploads are rejected before any request', () async {
    var called = false;
    await http.runWithClient(() async {
      final result = await ScanService.analyzeImage(XFile.fromData(Uint8List(ApiClient.maxImageBytes + 1), name: 'large.png'));
      expect(result['statusCode'], 413);
    }, () => MockClient((r) async { called = true; return http.Response('{}', 200); }));
    expect(called, false);
  });
  testWidgets('Requests time out instead of leaving a permanent spinner', (tester) async {
    await http.runWithClient(() async {
      final pending = AuthService.login(email: 'test@example.com', password: 'password123');
      await tester.pump();
      await tester.pump(const Duration(seconds: 26));
      final result = await pending;
      expect(result['success'], false);
      expect(result['message'], contains('too long'));
    }, () => MockClient((r) => Completer<http.Response>().future));
  });
  test('HTML server failures become useful messages', () async {
    await http.runWithClient(() async {
      final result = await AuthService.login(email: 'test@example.com', password: 'password123');
      expect(result['success'], false);
      expect(result['message'], isNot(contains('<html>')));
    }, () => MockClient((r) async => http.Response('<html>Gateway error</html>', 502)));
  });
  test('Google response matches state, nonce, audience and expiration', () {
    String token(Map<String,dynamic> claims) => 'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';
    final now = DateTime.utc(2026,10,18);
    final claims = <String,dynamic>{'nonce':'nonce','aud':'client','iss':'https://accounts.google.com','exp':now.millisecondsSinceEpoch ~/ 1000 + 60};
    bool check(Map<String,dynamic> value, {String state='state'}) => matchesGoogleResponse(
      token:token(value),state:state,expectedState:'state',nonce:'nonce',clientId:'client',now:now);
    expect(check(claims), true);
    expect(check(claims,state:'forged'), false);
    for(final change in [{'nonce':'wrong'}, {'aud':'wrong'}, {'exp':1}, {'iss':'https://attacker.example'}]) {
      expect(check({...claims,...change}), false);
    }
  });
}
