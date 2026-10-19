import 'dart:convert';

/// Browser correlation checks only. The API still verifies the Google signature.
bool matchesGoogleResponse({
  required String token,
  required String state,
  required String expectedState,
  required String nonce,
  required String clientId,
  required DateTime now,
}) {
  try {
    if (state != expectedState || expectedState.isEmpty) return false;
    final parts = token.split('.');
    if (parts.length != 3) return false;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return claims is Map &&
        claims['nonce'] == nonce &&
        claims['aud'] == clientId &&
        [
          'accounts.google.com',
          'https://accounts.google.com',
        ].contains(claims['iss']) &&
        claims['exp'] is num &&
        (claims['exp'] as num) * 1000 > now.millisecondsSinceEpoch;
  } catch (_) {
    return false;
  }
}
