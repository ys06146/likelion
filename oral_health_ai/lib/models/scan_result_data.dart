import 'scan_item.dart';

class ScanResultData {
  final double probability;
  final RiskLevel riskLevel;
  final String summary;
  final Map<String, String> details;
  final List<String> recommendations;

  const ScanResultData({
    required this.probability,
    required this.riskLevel,
    required this.summary,
    required this.details,
    required this.recommendations,
  });

  factory ScanResultData.fromPredictResponse(Map<String, dynamic> json) {
    return ScanResultData(
      probability: (json['prob_percent'] as num?)?.toDouble() ?? 0,
      riskLevel: ScanItem.fromApiLabel(json['level']?.toString()),
      summary: json['summary']?.toString() ?? '',
      details: const {},
      recommendations: _readRecommendations(json['recommendations']),
    );
  }

  factory ScanResultData.fromDetailResponse(Map<String, dynamic> json) {
    return ScanResultData(
      probability: (json['probability'] as num?)?.toDouble() ?? 0,
      riskLevel: ScanItem.fromApiLabel(json['status_labels']?.toString()),
      summary: json['status_labels']?.toString() ?? '',
      details: const {},
      recommendations: _readRecommendations(json['advice_list']),
    );
  }

  static List<String> _readRecommendations(dynamic rawRecommendations) {
    if (rawRecommendations is List) {
      return rawRecommendations.map((item) => item.toString()).toList();
    }

    return const [];
  }
}
