import 'dart:async';
import 'dart:io' show File;
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:nikki/core/constants/camera_colors.dart';
import 'package:nikki/theme/nikki_colors.dart';
import 'package:nikki/providers/camera_provider.dart';
import 'package:nikki/providers/explanation_provider.dart';
import 'package:nikki/providers/settings_provider.dart';
import 'package:nikki/services/ocr/apple_ocr_service.dart';
import 'package:nikki/services/ocr/ocr_service.dart';
import 'package:nikki/models/ocr.dart';
import 'package:nikki/widgets/explanation_sheet.dart';
import 'package:nikki/widgets/handle_draggable_sheet.dart';
import 'package:nikki/widgets/text_overlay.dart';

import 'package:nikki/screens/novel_detail/novel_detail_screen.dart';
import 'package:nikki/screens/camera/widgets/camera_permission_view.dart';
import 'package:nikki/screens/camera/widgets/camera_preview_layer.dart';
import 'package:nikki/screens/camera/widgets/camera_top_bar.dart';
import 'package:nikki/screens/camera/widgets/camera_bottom_bar.dart';
import 'package:nikki/screens/camera/widgets/new_novel_dialog.dart';

class CameraScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CameraScreen({super.key, this.onBack});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  final AppleOcrService _appleOcrService = AppleOcrService();
  final OcrService _googleOcrService = OcrService();
  bool _permissionGranted = false;
  bool _permissionPermanentlyDenied = false;
  List<CameraDescription>? _cameras;
  CameraDescription? _selectedCamera;
  bool _isShowingExplanation = false;
  bool _isTakingPicture = false;
  final TransformationController _transformController = TransformationController();
  AnimationController? _panAnimController;
  double _currentPanY = 0;

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

  bool _isInitializing = false;

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // Dispose any existing controller first.
      _controller?.dispose();
      _controller = null;

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty || !mounted) return;

      _selectedCamera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      final controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.max,
        enableAudio: false,
      );

      _controller = controller;
      await controller.initialize();
      if (!mounted || _controller != controller) return;

      _cameraSleeping = false;
      _resetIdleTimer();
      setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    } finally {
      _isInitializing = false;
    }
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
      final settings = context.read<SettingsProvider>();

      // Ensure settings are fully loaded before deciding OCR engine.
      await settings.ensureLoaded();

      final OcrResult result;
      if (settings.useGoogleOcr) {
        result = await _googleOcrService.processImageFile(
          xFile.path,
          cameraProvider.sourceLanguage,
          settings.googleCloudApiKey,
        );
      } else {
        result = await _appleOcrService.processImageFile(
          xFile.path,
          cameraProvider.sourceLanguage,
        );
      }
      if (!mounted) return;

      cameraProvider.onPictureTaken(
        xFile.path,
        result.blocks,
        result.width,
        result.height,
      );

      // Let the captured image layer render first, then stop camera
      // on the next frame to avoid a black flash.
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _stopCamera();
        });
      }
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
    _currentPanY = 0;
    _transformController.value = Matrix4.identity();
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

  void _onTextSelected(String selectedText, String blockText, [double selectionNormalizedY = 0]) {
    final cameraProvider = context.read<CameraProvider>();
    cameraProvider.onTextSelected(selectedText, blockText);

    if (selectionNormalizedY > 0.45) {
      final screenHeight = MediaQuery.of(context).size.height;
      final targetPanY = -(selectionNormalizedY - 0.3) * screenHeight;
      _animatePanTo(targetPanY);
    }

    // Always trigger a new explanation, even if the sheet is already open.
    final explanationProvider = context.read<ExplanationProvider>();
    final selectedWord = cameraProvider.selectedWord;
    if (selectedWord != null) {
      explanationProvider.explain(
        selectedText: selectedWord.text,
        surroundingContext: selectedWord.surroundingContext,
        sourceLanguage: cameraProvider.sourceLanguage,
        targetLanguage: cameraProvider.targetLanguage,
        novelId: cameraProvider.selectedNovel?.id,
        dontSave: cameraProvider.dontSave,
      );
    }

    _showExplanationSheet();
  }

  void _animatePanTo(double targetY) {
    _panAnimController?.dispose();
    _panAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final startY = _currentPanY;
    // Capture the current transform so we preserve zoom + X translation.
    final baseMatrix = Matrix4.copy(_transformController.value);
    final baseTransY = baseMatrix.getTranslation().y;
    final deltaY = targetY - startY;
    final animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _panAnimController!, curve: Curves.easeInOut),
    );
    animation.addListener(() {
      _currentPanY = startY + deltaY * animation.value;
      final m = Matrix4.copy(baseMatrix);
      m.setTranslationRaw(
        m.getTranslation().x,
        baseTransY + deltaY * animation.value,
        0,
      );
      _transformController.value = m;
    });
    _panAnimController!.forward();
  }

  void _resetPan() {
    if (_currentPanY == 0) return;
    _animatePanTo(0);
  }

  void _showExplanationSheet() {
    if (_isShowingExplanation) return;
    _isShowingExplanation = true;

    final colors = NikkiColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.dialogBg,
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
        _resetPan();
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
    _panAnimController?.dispose();
    _transformController.dispose();
    _appleOcrService.dispose();
    _googleOcrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Permission view OR camera preview
              if (!_permissionGranted)
                CameraPermissionView(
                  isPermanentlyDenied: _permissionPermanentlyDenied,
                  onRequestPermission: _requestPermissionAndInit,
                )
              else ...[
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
                    transformationController: _transformController,
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
                          transformController: _transformController,
                          onSelectionComplete: (text, block, y) => _onTextSelected(text, block, y),
                        ),
                      ],
                    ),
                  ),
                ),

              ], // end of else (camera preview + captured image)

              // Top bar
              CameraTopBar(
                sourceLanguage: cameraProvider.sourceLanguage,
                selectedNovel: cameraProvider.selectedNovel,
                onLanguageChanged: (lang) =>
                    cameraProvider.setSourceLanguage(lang),
                onArrowTap: widget.onBack ?? () => Navigator.pop(context),
                onNovelTap: cameraProvider.selectedNovel != null
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NovelDetailScreen(
                              novel: cameraProvider.selectedNovel!,
                            ),
                          ),
                        )
                    : null,
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
