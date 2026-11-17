import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/scan/mouth_guide.dart';
import 'analyzing_screen.dart';

/// Web: same Oral Scan UI as mobile (guide + shutter) but capture uses
/// [ImageSource.camera] — avoids importing `camera` (no web implementation).
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isCapturing = false;
  XFile? _selectedImage;

  Future<void> _pickImage(ImageSource source) async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);

      if (!mounted) return;

      setState(() => _isCapturing = false);

      if (picked == null) return;
      setState(() {
        _selectedImage = picked;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo selection failed: $e')),
      );
    }
  }

  Future<void> _openAnalyzingScreen() async {
    final selectedImage = _selectedImage;
    if (selectedImage == null || _isCapturing) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalyzingScreen(imageFile: selectedImage),
      ),
    );
  }

  Widget _buildTopBar() {
    final busy = _isCapturing;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(top: 52, left: 18, right: 18, bottom: 14),
      child: Row(
        children: [
          IconButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Oral Scan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: null,
            icon: Icon(
              Icons.flash_off,
              color: Colors.white.withValues(alpha: 0.45),
              size: 20,
            ),
            tooltip: 'Flash not available in browser',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final disabled = _isCapturing;

    if (_selectedImage != null) {
      return Container(
        height: 96,
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: disabled
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Choose Another'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FilledButton(
                onPressed: disabled ? null : _openAnalyzingScreen,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF109796),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Use This Photo'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 96,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: disabled ? null : () => _pickImage(ImageSource.gallery),
            icon: const Icon(
              Icons.replay_outlined,
              color: Colors.white,
              size: 24,
            ),
            tooltip: 'Choose from gallery',
          ),
          GestureDetector(
            onTap: disabled ? null : () => _pickImage(ImageSource.camera),
            child: Opacity(
              opacity: disabled ? 0.5 : 1,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _selectedImage == null
                          ? const ColoredBox(color: Colors.black)
                          : Image.network(
                              _selectedImage!.path,
                              fit: BoxFit.contain,
                            ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color.fromRGBO(0, 0, 0, 0.32),
                              Color.fromRGBO(0, 0, 0, 0.08),
                              Color.fromRGBO(0, 0, 0, 0.32),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, -40),
                    child: const MouthGuide(),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.72),
                  child: Text(
                    'Position your mouth within the guide',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }
}
