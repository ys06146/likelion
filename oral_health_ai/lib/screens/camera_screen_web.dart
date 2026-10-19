import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../services/scan_service.dart';
import 'camera_scan_helpers.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  XFile? _file;
  Uint8List? _preview;
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file == null) return;
      if (await file.length() > ApiClient.maxImageBytes) {
        throw const ApiException('Choose an image smaller than 10 MB.');
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _file = file;
          _preview = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not open the image. Please choose another file.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    final file = _file;
    if (_busy || file == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ScanService.analyzeImage(file);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['success'] == true) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(result: scanResultFromAnalyzeMap(result)),
        ),
      );
    } else {
      setState(
        () => _error =
            result['message']?.toString() ??
            'Analysis failed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New scan')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Choose a clear photo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Use a well-lit photo of your teeth. JPEG, PNG or WebP, up to 10 MB and 20 megapixels.',
            ),
            const SizedBox(height: 20),
            if (_preview != null)
              Image.memory(
                _preview!,
                height: 240,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) => const SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'This image cannot be previewed. Choose a JPEG, PNG or WebP file.',
                    ),
                  ),
                ),
              )
            else
              const SizedBox(
                height: 160,
                child: Center(
                  child: Icon(Icons.add_photo_alternate_outlined, size: 64),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photo'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Take photo'),
            ),
            const Text(
              'Camera availability depends on your browser and device. You can always choose a saved photo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _busy || _file == null ? null : _analyze,
              child: Text(_busy ? 'Please wait...' : 'Analyze photo'),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 16),
            const Text(
              'Results are experimental image-level scores, not a medical diagnosis.',
            ),
          ],
        ),
      ),
    ),
  );
}
