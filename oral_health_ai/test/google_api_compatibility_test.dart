import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oral_health_ai/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Google login supplies the email required by the production API',
    () async {
      SharedPreferences.setMockInitialValues({});
      await http.runWithClient(
        () async {
          final result = await AuthService.loginWithIdToken(
            idToken: 'test-google-token',
            email: 'google-test@example.com',
          );
          expect(result['success'], isTrue);
          expect(await AuthService.getToken(), 'test-session');
        },
        () => MockClient((request) async {
          expect(request.url.path, '/auth/google/mobile');
          expect(jsonDecode(request.body), {
            'id_token': 'test-google-token',
            'email': 'google-test@example.com',
          });
          return http.Response(
            '{"access_token":"test-session","token_type":"bearer",'
            '"email":"google-test@example.com","profile":{}}',
            200,
          );
        }),
      );
    },
  );
}
