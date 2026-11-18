import 'package:flutter/material.dart';
import '../models/scan_item.dart';
import '../models/scan_result_data.dart';
import '../services/scan_service.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/summary_card.dart';
import '../widgets/home/scan_row.dart';
import '../widgets/home/start_scan_button.dart';
import 'profile_screen.dart';
import 'camera_screen.dart';
import 'result_detail_screen.dart';
import 'compare_scans_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ScanItem> scans = [];
  bool isLoading = true;
  bool isOpeningDetail = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    final result = await ScanService.getHistory();
    if (!mounted) return;
    setState(() {
      isLoading = false;
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        scans = (data['recent_scans'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ScanItem.fromJson)
            .toList();
      } else {
        error = result['message']?.toString() ?? 'Could not load scan history.';
      }
    });
  }

  Future<void> _openScanDetail(ScanItem item) async {
    if (isOpeningDetail) return;
    setState(() => isOpeningDetail = true);
    final response = await ScanService.getScanDetail(item.scanId);
    if (!mounted) return;
    setState(() => isOpeningDetail = false);
    if (response['success'] == true) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultDetailScreen(
            result: ScanResultData.fromDetailResponse(
              response['data'] as Map<String, dynamic>,
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response['message'].toString())));
    }
  }

  Future<void> _deleteScan(ScanItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scan?'),
        content: Text(
          'The saved result from ${item.date} will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ScanService.deleteScan(item.scanId);
    if (!mounted) return;
    if (result['success'] == true) {
      await _loadHistory();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'].toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _loadHistory,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HomeHeader(
                          onProfileTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SummaryCard(
                          lastScanResult: scans.isEmpty
                              ? 'No scans yet'
                              : scans.first.label,
                          totalScans: scans.length,
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompareScansScreen(scans: scans),
                            ),
                          ),
                          icon: const Icon(Icons.compare_arrows),
                          label: const Text('Compare Past Scans'),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'SAVED SCANS',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (isOpeningDetail) const LinearProgressIndicator(),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(error!),
                          TextButton(
                            onPressed: _loadHistory,
                            child: const Text('Retry'),
                          ),
                        ],
                        if (!isLoading && error == null && scans.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No scans yet. Upload a photo to save your first result.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: scans.length,
                    itemBuilder: (context, index) => Row(
                      children: [
                        Expanded(
                          child: ScanRow(
                            item: scans[index],
                            onTap: () => _openScanDetail(scans[index]),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete scan ${scans[index].scanId}',
                          onPressed: () => _deleteScan(scans[index]),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StartScanButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                );
                if (mounted) await _loadHistory();
              },
            ),
          ),
        ),
      ),
    ),
  );
}
