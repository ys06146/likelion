import 'dart:async';
import 'dart:math';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'api_client.dart';
import 'google_oauth_validation.dart';

extension type _MessageData._(JSObject _) implements JSObject {
  external String? get type;
  @JS('id_token')
  external String? get idToken;
  external String? get state;
  external String? get error;
}

String _randomToken() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Future<String> signInWithGoogle({required String clientId}) async {
  final origin = web.window.location.origin;
  final base = web.document.querySelector('base')?.getAttribute('href') ?? '/';
  final redirectUri = Uri.parse(
    web.window.location.href,
  ).resolve(base).toString();
  final nonce = _randomToken();
  final state = _randomToken();
  final completer = Completer<String>();
  web.Window? popup;
  final listener = ((web.Event e) {
    final event = e as web.MessageEvent;
    if (event.origin != origin ||
        event.source != popup ||
        completer.isCompleted) {
      return;
    }
    try {
      final data = event.data as _MessageData;
      if (data.type != 'google_id_token' || data.state != state) return;
      if (data.error != null) {
        completer.completeError(
          const ApiException('Google sign-in was cancelled or denied.'),
        );
      } else if (data.idToken != null &&
          matchesGoogleResponse(
            token: data.idToken!,
            state: data.state!,
            expectedState: state,
            nonce: nonce,
            clientId: clientId,
            now: DateTime.now(),
          )) {
        completer.complete(data.idToken!);
      } else {
        completer.completeError(
          const ApiException(
            'Google sign-in could not be verified. Please try again.',
          ),
        );
      }
    } catch (_) {
      if (!completer.isCompleted) {
        completer.completeError(const ApiException('Invalid Google response.'));
      }
    }
  }).toJS;
  web.window.addEventListener('message', listener);
  final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'id_token',
    'scope': 'openid email profile',
    'nonce': nonce,
    'state': state,
    'prompt': 'select_account',
  });
  Timer? closedTimer;
  try {
    popup = web.window.open(
      url.toString(),
      'oraq_google_signin',
      'width=500,height=600',
    );
    if (popup == null) {
      throw const ApiException(
        'Allow pop-ups for this site to sign in with Google.',
      );
    }
    closedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      try {
        if (popup!.closed && !completer.isCompleted) {
          completer.completeError(
            const ApiException('Google sign-in was cancelled.'),
          );
        }
      } catch (_) {
        /* Cross-origin popup access can be restricted until it returns. */
      }
    });
    return await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw const ApiException(
        'Google sign-in timed out. Please try again.',
      ),
    );
  } finally {
    closedTimer?.cancel();
    web.window.removeEventListener('message', listener);
    try {
      popup?.close();
    } catch (_) {}
  }
}
