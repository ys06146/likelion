import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_service.dart';

class ScanService {
  static Future<Map<String, dynamic>> _authorized(
    Future<Map<String, dynamic>> Function(String token) operation,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw const ApiException('Please sign in again.', 401);
      return await operation(token);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await AuthService.logout(expired: true);
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

  static Future<Map<String, dynamic>> analyzeImage(
    XFile imageFile,
  ) => _authorized((token) async {
    if (await imageFile.length() > ApiClient.maxImageBytes) {
      throw const ApiException('Choose an image smaller than 10 MB.', 413);
    }
    final bytes = await imageFile.readAsBytes();
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${ApiClient.baseUrl}/scans/predict'),
          )
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              bytes,
              filename: imageFile.name.isEmpty ? 'scan.jpg' : imageFile.name,
            ),
          );
    final body = await ApiClient.send(
      request,
      token: token,
      timeout: ApiClient.uploadTimeout,
    );
    final probability = body['prob_percent'];
    final level = body['level']?.toString().toLowerCase();
    if (probability is! num ||
        !probability.isFinite ||
        probability < 0 ||
        probability > 100 ||
        !['risk', 'caution', 'normal'].contains(level)) {
      throw const ApiException(
        'The server returned an invalid analysis result.',
      );
    }
    return {
      'success': true,
      'riskPercent': probability.toDouble(),
      'riskType': level == 'risk' ? 'highRisk' : level,
      'message': '${body['level']} model score',
      // Legacy servers return fixed findings; they are not model measurements.
      'details': <String, String>{},
      'recommendations': [
        'This experimental score is not a medical diagnosis.',
        'Consult a dental professional about symptoms or concerns, regardless of the score.',
      ],
      'raw': body,
    };
  });

  static Future<Map<String, dynamic>> getHistory() => _authorized(
    (token) async => {
      'success': true,
      'data': await ApiClient.request('GET', '/scans/history', token: token),
    },
  );
  static Future<Map<String, dynamic>> getScanDetail(int id) => _authorized(
    (token) async => {
      'success': true,
      'data': await ApiClient.request('GET', '/scans/detail/$id', token: token),
    },
  );
  static Future<Map<String, dynamic>> deleteScan(int id) => _authorized(
    (token) async => {
      'success': true,
      'data': await ApiClient.request(
        'DELETE',
        '/scans/delete/$id',
        token: token,
      ),
    },
  );
}
