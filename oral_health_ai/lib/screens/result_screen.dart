import 'package:flutter/material.dart';
import '../models/scan_item.dart';
import '../models/scan_result_data.dart';
import 'result_detail_screen.dart';

class ResultScreen extends StatelessWidget {
  final ScanResultData result;

  const ResultScreen({super.key, required this.result});

  _ResultConfig _getConfig() {
    switch (result.riskLevel) {
      case RiskLevel.normal:
        return _ResultConfig(
          title: result.summary.isEmpty ? 'Normal' : result.summary,
          subtitle:
              'A low image-level model score does not rule out a dental problem.',
          accentColor: const Color(0xFF0C8A8A),
          iconBgColor: const Color(0xFFE8F2F2),
          bottomSectionTitle: 'RECOMMENDATIONS',
          details: _buildDetails(),
          steps: _buildSteps(),
          showDisclaimer: true,
        );
      case RiskLevel.caution:
        return _ResultConfig(
          title: result.summary.isEmpty ? 'Caution' : result.summary,
          subtitle: 'The model returned an intermediate image-level score.',
          accentColor: const Color(0xFFFF9500),
          iconBgColor: null,
          bottomSectionTitle: 'RECOMMENDATIONS',
          details: _buildDetails(),
          steps: _buildSteps(),
          showDisclaimer: true,
        );
      case RiskLevel.highRisk:
        return _ResultConfig(
          title: result.summary.isEmpty ? 'High model score' : result.summary,
          subtitle:
              'The model returned a high image-level score. Review the report and consult a dental professional.',
          accentColor: const Color(0xFFFF453A),
          iconBgColor: null,
          bottomSectionTitle: 'NEXT STEPS',
          details: _buildDetails(),
          steps: _buildSteps(),
          showDisclaimer: true,
        );
    }
  }

  List<_DetailItem> _buildDetails() {
    final items = result.details.entries
        .map(
          (entry) => _DetailItem(
            _formatLabel(entry.key),
            entry.value,
            _valueColor(entry.value),
          ),
        )
        .toList();

    items.add(
      _DetailItem(
        'Model score',
        '${result.probability.toStringAsFixed(result.probability % 1 == 0 ? 0 : 1)}%',
        _accentColor,
      ),
    );

    return items;
  }

  List<String> _buildSteps() {
    if (result.recommendations.isNotEmpty) {
      return result.recommendations;
    }

    return const ['Keep up with regular oral hygiene and monitor any changes.'];
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

  Color _valueColor(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('normal') ||
        lower.contains('healthy') ||
        lower.contains('excellent')) {
      return const Color(0xFF0C8A8A);
    }
    if (lower.contains('moderate') || lower.contains('caution')) {
      return const Color(0xFFFF9500);
    }
    if (lower.contains('risk') ||
        lower.contains('needs') ||
        lower.contains('concern')) {
      return const Color(0xFFFF453A);
    }
    return _accentColor;
  }

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

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

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
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: Column(
                  children: [
                    _buildTopResult(config),
                    const SizedBox(height: 26),
                    _SectionTitle(title: 'DETAILS'),
                    const SizedBox(height: 10),
                    _CardContainer(
                      child: Column(
                        children: List.generate(config.details.length, (index) {
                          final item = config.details[index];
                          final isLast = index == config.details.length - 1;
                          return _DetailRow(
                            label: item.label,
                            value: item.value,
                            valueColor: item.color,
                            isLast: isLast,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionTitle(title: config.bottomSectionTitle),
                    const SizedBox(height: 10),
                    _CardContainer(
                      child: Column(
                        children: List.generate(config.steps.length, (index) {
                          final isLast = index == config.steps.length - 1;
                          return _StepRow(
                            index: index + 1,
                            text: config.steps[index],
                            isLast: isLast,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PrimaryButton(
                      text: 'View Detailed Report',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultDetailScreen(result: result),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Scan Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0C8A8A),
                        ),
                      ),
                    ),
                    if (config.showDisclaimer) ...[
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopResult(_ResultConfig config) {
    if (result.riskLevel == RiskLevel.normal) {
      return Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: config.iconBgColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 36, color: Color(0xFF0C8A8A)),
          ),
          const SizedBox(height: 18),
          Text(
            config.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            config.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFFA3A3AA),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          '${result.probability.toStringAsFixed(result.probability % 1 == 0 ? 0 : 1)}%',
          style: TextStyle(
            fontSize: 58,
            height: 1,
            fontWeight: FontWeight.w800,
            color: config.accentColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          config.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          config.subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Color(0xFFA3A3AA),
          ),
        ),
      ],
    );
  }
}

class _ResultConfig {
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color? iconBgColor;
  final String bottomSectionTitle;
  final List<_DetailItem> details;
  final List<String> steps;
  final bool showDisclaimer;

  const _ResultConfig({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.iconBgColor,
    required this.bottomSectionTitle,
    required this.details,
    required this.steps,
    required this.showDisclaimer,
  });
}

class _DetailItem {
  final String label;
  final String value;
  final Color color;

  const _DetailItem(this.label, this.value, this.color);
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9B9BA1),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: Color(0xFFEAEAF0)),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;
  final bool isLast;

  const _StepRow({
    required this.index,
    required this.text,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFADADB4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: Color(0xFFEAEAF0)),
      ],
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
