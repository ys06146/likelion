import 'package:flutter/material.dart';
import '../models/scan_item.dart';
import '../models/scan_result_data.dart';

class ResultDetailScreen extends StatelessWidget {
  final ScanResultData result;

  const ResultDetailScreen({super.key, required this.result});

  Color get _accentColor {
    switch (result.riskLevel) {
      case RiskLevel.normal:
        return const Color(0xFF0C8A8A);
      case RiskLevel.caution:
        return const Color(0xFFFF9500);
      case RiskLevel.highRisk:
        return const Color(0xFFFF453A);
    }
  }

  Color get _badgeBackground {
    switch (result.riskLevel) {
      case RiskLevel.normal:
        return const Color(0xFFE8F6F3);
      case RiskLevel.caution:
        return const Color(0xFFFFF4E5);
      case RiskLevel.highRisk:
        return const Color(0xFFFFF1F0);
    }
  }

  String get _statusLabel {
    switch (result.riskLevel) {
      case RiskLevel.normal:
        return 'Normal';
      case RiskLevel.caution:
        return 'Caution';
      case RiskLevel.highRisk:
        return 'High model score';
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailEntries = result.details.entries.toList();
    final primaryRecommendation = result.recommendations.isEmpty
        ? 'Keep monitoring your oral condition and maintain a consistent hygiene routine.'
        : result.recommendations.first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.chevron_left,
                          color: Color(0xFF0C8A8A),
                          size: 22,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: Color(0xFF0C8A8A),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Results',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 58),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F2)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: _accentColor),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'This model provides an image-level score. Individual teeth, gums and plaque are not assessed.',
                      style: TextStyle(fontSize: 14, color: Color(0xFFA6A6AD)),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 20),
                    _InfoCard(
                      child: Column(
                        children: [
                          _RiskSummaryHeader(
                            title: _statusLabel,
                            subtitle: result.summary,
                            accentColor: _accentColor,
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFEAEAF0),
                          ),
                          _DetailMetricRow(
                            label: 'Model score',
                            value:
                                '${result.probability.toStringAsFixed(result.probability % 1 == 0 ? 0 : 1)}%',
                            valueColor: _accentColor,
                          ),
                          ...List.generate(detailEntries.length, (index) {
                            final entry = detailEntries[index];
                            final isLast = index == detailEntries.length - 1;
                            return Column(
                              children: [
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFEAEAF0),
                                ),
                                _DetailMetricRow(
                                  label: _formatLabel(entry.key),
                                  value: entry.value,
                                  valueColor: _accentColor,
                                  isLast: isLast,
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: _accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusLabel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  primaryRecommendation,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFB2B2B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PrimaryButton(
                      text: 'Back To Previous Screen',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0C8A8A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'This is not a medical diagnosis. Please consult\na healthcare professional for medical advice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFFC0C0C6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLabel(String key) {
    return key
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;

  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _RiskSummaryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const _RiskSummaryHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor, width: 1.8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Color(0xFFA6A6AD)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isLast;

  const _DetailMetricRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, isLast ? 16 : 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF067E80),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x33067E80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
