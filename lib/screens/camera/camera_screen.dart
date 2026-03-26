import 'dart:async';
import 'dart:io' show File;
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/services/ocr/apple_ocr_service.dart';
import 'package:nikki/widgets/explanation_sheet.dart';
import 'package:nikki/widgets/handle_draggable_sheet.dart';
import 'package:nikki/widgets/text_overlay.dart';

import 'package:nikki/screens/camera/widgets/camera_permission_view.dart';
import 'package:nikki/screens/camera/widgets/camera_preview_layer.dart';
import 'package:nikki/screens/camera/widgets/camera_top_bar.dart';
import 'package:nikki/screens/camera/widgets/camera_bottom_bar.dart';
import 'package:nikki/screens/camera/widgets/new_novel_dialog.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final AppleOcrService _ocrService = AppleOcrService();
  bool _permissionGranted = false;
  bool _permissionPermanentlyDenied = false;
  List<CameraDescription>? _cameras;
  CameraDescription? _selectedCamera;
  bool _isShowingExplanation = false;
  bool _isTakingPicture = false;

  // Camera idle sleep
  static const _idleTimeout = Duration(seconds: 8);
  static const _motionThreshold = 0.3;
  bool _cameraSleeping = false;
  Timer? _idleTimer;
  StreamSubscription<dynamic>? _accelSub;
  double _lastAccelMag = 0;

  /// Path to the last frame snapshot — shown blurred when camera sleeps
  /// or during retake while camera re-initializes.
  String? _lastFramePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCurrentStatus();
    _startMotionDetection();
  }

  Future<void> _checkCurrentStatus() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _permissionGranted = true);
      await _initCamera();
    } else {
      setState(() {
        _permissionPermanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _permissionGranted = status.isGranted;
      _permissionPermanentlyDenied = status.isPermanentlyDenied;
    });
    if (_permissionGranted) {
      await _initCamera();
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;

    _selectedCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      _selectedCamera!,
      ResolutionPreset.max,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    _cameraSleeping = false;
    _resetIdleTimer();
    setState(() {});
  }

  void _stopCamera() {
    _idleTimer?.cancel();
    _controller?.dispose();
    _controller = null;
  }

  void _sleepCamera() {
    if (_cameraSleeping || _controller == null) return;
    debugPrint('Camera: sleeping (idle timeout)');
    _stopCamera();
    if (mounted) setState(() => _cameraSleeping = true);
  }

  Future<void> _wakeCamera() async {
    if (!_cameraSleeping || !_permissionGranted) return;
    debugPrint('Camera: waking up');
    setState(() => _cameraSleeping = false);
    await _initCamera();
  }

  // ── Motion detection ──────────────────────────────────────────────

  void _startMotionDetection() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 500),
      ).handleError((_) {
        debugPrint('Accelerometer stream error, using touch-only idle');
        _accelSub?.cancel();
        _accelSub = null;
      }).listen((event) {
        final mag =
            sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final delta = (mag - _lastAccelMag).abs();
        _lastAccelMag = mag;

        if (delta > _motionThreshold) {
          _onActivity();
        }
      });
    } catch (_) {
      debugPrint('Accelerometer init failed, using touch-only idle');
    }
  }

  void _onActivity() {
    if (_cameraSleeping) {
      _wakeCamera();
    } else {
      _resetIdleTimer();
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    final cameraProvider = context.read<CameraProvider>();
    if (cameraProvider.isCaptured) return;
    _idleTimer = Timer(_idleTimeout, _sleepCamera);
  }

  void _deleteTempFile(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  // ── Capture / Retake ──────────────────────────────────────────────

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);
    _idleTimer?.cancel();

    try {
      final xFile = await _controller!.takePicture();
      if (!mounted) return;

      final cameraProvider = context.read<CameraProvider>();
      final result = await _ocrService.processImageFile(
        xFile.path,
        cameraProvider.sourceLanguage,
      );
      if (!mounted) return;

      cameraProvider.onPictureTaken(
        xFile.path,
        result.blocks,
        result.width,
        result.height,
      );

      _stopCamera();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Take picture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  void _retake() {
    final cameraProvider = context.read<CameraProvider>();
    final oldPath = cameraProvider.capturedImagePath;
    _lastFramePath = oldPath;
    cameraProvider.retake();
    _initCamera();
    Future.delayed(const Duration(seconds: 2), () => _deleteTempFile(oldPath));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _idleTimer?.cancel();
      _stopCamera();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      final cameraProvider = context.read<CameraProvider>();
      if (!_permissionGranted) {
        _checkCurrentStatus();
      } else if (!cameraProvider.isCaptured) {
        _cameraSleeping = false;
        _initCamera();
      }
    }
  }

  void _onTextSelected(String selectedText, String blockText) {
    final cameraProvider = context.read<CameraProvider>();
    cameraProvider.onTextSelected(selectedText, blockText);
    _showExplanationSheet();
  }

  void _showExplanationSheet() {
    if (_isShowingExplanation) return;
    _isShowingExplanation = true;

    final cameraProvider = context.read<CameraProvider>();
    final explanationProvider = context.read<ExplanationProvider>();
    final selectedWord = cameraProvider.selectedWord;

    if (selectedWord == null) {
      _isShowingExplanation = false;
      return;
    }

    explanationProvider.explain(
      selectedText: selectedWord.text,
      surroundingContext: selectedWord.surroundingContext,
      sourceLanguage: cameraProvider.sourceLanguage,
      targetLanguage: cameraProvider.targetLanguage,
      novelId: cameraProvider.selectedNovel?.id,
      dontSave: cameraProvider.dontSave,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CameraColors.linen,
      barrierColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return const HandleDraggableSheet(
          initialFraction: 0.45,
          maxFraction: 0.85,
          child: ExplanationSheet(),
        );
      },
    ).whenComplete(() {
      _isShowingExplanation = false;
      if (mounted) {
        context.read<CameraProvider>().dismissExplanation();
        context.read<ExplanationProvider>().reset();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _accelSub?.cancel();
    _controller?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionGranted) {
      return CameraPermissionView(
        isPermanentlyDenied: _permissionPermanentlyDenied,
        onRequestPermission: _requestPermissionAndInit,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview + sleep overlay
              CameraPreviewLayer(
                controller: _controller,
                isCaptured: cameraProvider.isCaptured,
                isSleeping: _cameraSleeping,
                lastFramePath: _lastFramePath,
                onWakeTap: _wakeCamera,
              ),

              // Captured image + text overlay
              if (cameraProvider.isCaptured)
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(cameraProvider.capturedImagePath!),
                          fit: BoxFit.cover,
                        ),
                        TextOverlay(
                          blocks: cameraProvider.recognizedBlocks,
                          selectedWord: cameraProvider.selectedWord,
                          imageWidth: cameraProvider.imageWidth,
                          imageHeight: cameraProvider.imageHeight,
                          rotationDegrees: 0,
                          imagePath: cameraProvider.capturedImagePath,
                          onSelectionComplete: _onTextSelected,
                        ),
                      ],
                    ),
                  ),
                ),

              // Top bar
              CameraTopBar(
                sourceLanguage: cameraProvider.sourceLanguage,
                novels: cameraProvider.novels,
                selectedNovel: cameraProvider.selectedNovel,
                onLanguageChanged: (lang) =>
                    cameraProvider.setSourceLanguage(lang),
                onNovelSelected: (novel) =>
                    cameraProvider.selectNovel(novel),
                onNewNovel: () => showNewNovelDialog(context),
                onArrowTap: () {
                  // TODO: action for arrow button
                },
              ),

              // Bottom bar
              CameraBottomBar(
                isCaptured: cameraProvider.isCaptured,
                isTakingPicture: _isTakingPicture,
                onCapture: _takePicture,
                onRetake: _retake,
                onHistoryTap: () =>
                    Navigator.pushNamed(context, '/history'),
              ),
            ],
          );
        },
      ),
    );
  }
}
