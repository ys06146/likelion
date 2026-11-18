import 'api_client.dart';

Future<String> signInWithGoogle({required String clientId}) async =>
    throw const ApiException('Google sign-in is available in the web app.');
