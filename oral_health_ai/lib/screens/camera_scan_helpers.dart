import '../models/scan_item.dart';
import '../models/scan_result_data.dart';

RiskLevel mapScanRiskLevel(String raw) {
  final level = raw.toLowerCase().trim();

  if (level == 'risk' || level == 'highrisk' || level == 'high_risk') {
    return RiskLevel.highRisk;
  }
  if (level == 'caution' || level == 'warning' || level == 'moderate') {
    return RiskLevel.caution;
  }
  return RiskLevel.normal;
}

ScanResultData scanResultFromAnalyzeMap(Map<String, dynamic> result) {
  final riskTypeString = result['riskType']?.toString() ?? 'normal';
  final double riskPercent = (result['riskPercent'] as num?)?.toDouble() ?? 0;

  final String summary = result['message']?.toString().trim().isNotEmpty == true
      ? result['message'].toString()
      : riskTypeString == 'highRisk'
      ? 'High Risk Detected'
      : riskTypeString == 'caution'
      ? 'Caution'
      : 'Normal';

  final detailsRaw = result['details'];
  final recsRaw = result['recommendations'];

  final Map<String, String> details = {};
  if (detailsRaw is Map) {
    for (final entry in detailsRaw.entries) {
      details[entry.key.toString()] = entry.value.toString();
    }
  }

  final List<String> recommendations = [];
  if (recsRaw is List) {
    for (final item in recsRaw) {
      recommendations.add(item.toString());
    }
  }

  return ScanResultData(
    probability: riskPercent.toDouble(),
    riskLevel: mapScanRiskLevel(riskTypeString),
    summary: summary,
    details: details,
    recommendations: recommendations,
  );
}
