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
  bool _isPicking = false;
  bool _isAnalyzing = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    if (_isPicking || _isAnalyzing) return;
    setState(() {
      _isPicking = true;
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
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _analyze() async {
    final file = _file;
    if (_isPicking || _isAnalyzing || file == null) return;
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });
    final result = await ScanService.analyzeImage(file);
    if (!mounted) return;
    final succeeded = result['success'] == true;
    setState(() {
      _isAnalyzing = false;
      if (succeeded) {
        _file = null;
        _preview = null;
      } else {
        _error =
            result['message']?.toString() ??
            'Analysis failed. Please try again.';
      }
    });
    if (succeeded) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(result: scanResultFromAnalyzeMap(result)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isAnalyzing,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('New scan'),
        automaticallyImplyLeading: !_isAnalyzing,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: _isAnalyzing
                ? const [
                    LinearProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing your photo…', textAlign: TextAlign.center),
                  ]
                : [
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
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 64,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: _isPicking
                          ? null
                          : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _file == null ? 'Choose photo' : 'Choose Another',
                      ),
                    ),
                    if (_file != null)
                      FilledButton(
                        onPressed: _isPicking ? null : _analyze,
                        child: const Text('Use This Photo'),
                      ),
                    TextButton.icon(
                      onPressed: _isPicking
                          ? null
                          : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take photo'),
                    ),
                    const Text(
                      'Camera availability depends on your browser and device. You can always choose a saved photo.',
                      textAlign: TextAlign.center,
                    ),
                    if (_isPicking)
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
    ),
  );
}
