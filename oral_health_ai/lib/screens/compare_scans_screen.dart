import 'package:flutter/material.dart';
import '../models/scan_item.dart';

class CompareScansScreen extends StatefulWidget {
  final List<ScanItem> scans;
  const CompareScansScreen({super.key, required this.scans});
  @override
  State<CompareScansScreen> createState() => _CompareScansScreenState();
}

class _CompareScansScreenState extends State<CompareScansScreen> {
  int first = 0;
  int second = 1;

  Widget _selection(
    String label,
    int index,
    ValueChanged<int> select,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      DropdownButton<int>(
        isExpanded: true,
        value: index,
        items: List.generate(
          widget.scans.length,
          (i) => DropdownMenuItem(
            value: i,
            child: Text(
              '#${widget.scans[i].scanId} · ${widget.scans[i].date}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        onChanged: (value) {
          if (value != null) setState(() => select(value));
        },
      ),
      Text(
        '${widget.scans[index].formattedPercent} · ${widget.scans[index].label}',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final enough = widget.scans.length >= 2;
    final delta = enough
        ? widget.scans[first].riskPercent - widget.scans[second].riskPercent
        : 0.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Past Scans')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!enough)
                const Text('Save at least two scans to compare model scores.'),
              if (enough) ...[
                _selection('First scan', first, (v) => first = v),
                const SizedBox(height: 24),
                _selection('Second scan', second, (v) => second = v),
                const SizedBox(height: 32),
                Text(
                  first == second
                      ? 'Choose two different scans.'
                      : 'First minus second: ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} percentage points',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'These are experimental image-level scores. Differences in photos and lighting can affect them; a change does not establish a change in dental health.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
