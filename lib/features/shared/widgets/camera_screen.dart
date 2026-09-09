import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  int _selectedCameraIndex = 0;
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hanya satu kamera aktif per waktu: saat app di-background, lepas kamera
    // agar tidak konflik dengan scanner/kamera lain (plan #15-#17, #38).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _wasInBackground = true;
      _disposeController();
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      // Re-init kamera setelah kembali ke foreground.
      if (_cameras != null && _cameras!.isNotEmpty) {
        _onNewCameraSelected(_cameras![_selectedCameraIndex]);
      } else {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _onNewCameraSelected(_cameras![_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    await _disposeController();

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
    }
  }

  Future<void> _disposeController() async {
    final old = _controller;
    _controller = null;
    if (old != null) {
      try {
        await old.dispose();
      } catch (e) {
        debugPrint('Error disposing camera controller: $e');
      }
    }
    if (mounted && _isInitialized) {
      setState(() {
        _isInitialized = false;
      });
    }
  }

  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _onNewCameraSelected(_cameras![_selectedCameraIndex]);
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile photo = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, photo);
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Center(
            child: CameraPreview(_controller!),
          ),

          // Overlay Header
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Platform info
          Positioned(
            top: 50,
            width: MediaQuery.of(context).size.width,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  Platform.isWindows ? 'Webcam Mode (Windows)' : 'Camera Mode',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Posisikan bukti pengiriman di tengah layar',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Switch Camera
                    if (_cameras != null && _cameras!.length > 1)
                      IconButton(
                        onPressed: _toggleCamera,
                        icon: const Icon(Icons.flip_camera_ios_rounded,
                            color: Colors.white, size: 32),
                      )
                    else
                      const SizedBox(width: 48),

                    // Capture Button
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
