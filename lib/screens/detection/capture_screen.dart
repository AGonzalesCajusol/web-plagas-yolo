import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ai_service.dart';
import '../../services/detection_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  Map<String, dynamic>? _lastDetection;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await AIService.instance.loadModel();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar el modelo de IA: $error'),
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
        _lastDetection = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir ${source == ImageSource.camera ? 'la cámara' : 'la galería'}: $error',
          ),
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _takePhoto() async {
    await _pickImage(ImageSource.camera);
  }

  Future<Position> _determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('El servicio de ubicación está deshabilitado.');
        return _defaultPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permiso de ubicación denegado.');
          return _defaultPosition();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permiso de ubicación denegado permanentemente.');
        return _defaultPosition();
      }

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return lastKnownPosition;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    } on TimeoutException catch (error) {
      debugPrint('Tiempo agotado obteniendo ubicación: $error');
      return _defaultPosition();
    } catch (error) {
      debugPrint('Error obteniendo ubicación: $error');
      return _defaultPosition();
    }
  }

  Position _defaultPosition() {
    return Position(
      latitude: 0.0,
      longitude: 0.0,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  Future<void> _analyzeCrop() async {
    if (_selectedImageBytes == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    _showLoadingDialog();

    try {
      double latitude = 0.0;
      double longitude = 0.0;

      try {
        final position = await _determinePosition();
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (locationError) {
        debugPrint('No se pudo obtener la ubicación: $locationError');
      }

      final resultado = await AIService.instance.analyzeImage(
        _selectedImageBytes!,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        _lastDetection = resultado;
      });
      _showResultBottomSheet(
        resultado,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo analizar la imagen: $error'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _showLoadingDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Row(
            children: [
              CircularProgressIndicator(
                color: colorScheme.primary,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Analizando imagen...',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResultBottomSheet(
    Map<String, dynamic> resultado, {
    required double latitude,
    required double longitude,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final plaga = resultado['plaga']?.toString() ?? 'Resultado desconocido';
    final confianza = resultado['confianza'];
    final confianzaValor = confianza is num ? confianza.toDouble() : 0.0;
    final confianzaPorcentaje = (confianzaValor * 100).round();
    var isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.eco_outlined,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Resultado de detección',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Plaga detectada',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  plaga,
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Confianza',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: confianzaValor.clamp(0.0, 1.0).toDouble(),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(999),
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$confianzaPorcentaje%',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Lat: ${latitude.toStringAsFixed(6)}, Lon: ${longitude.toStringAsFixed(6)}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: StatefulBuilder(
                    builder: (buttonContext, setButtonState) {
                      return FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final imageBytes = _selectedImageBytes;
                                if (imageBytes == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No hay imagen para guardar.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setButtonState(() {
                                  isSaving = true;
                                });

                                final success =
                                    await DetectionService().saveDetection(
                                  plagaNombre: plaga,
                                  confianza: confianzaValor,
                                  latitud: latitude,
                                  longitud: longitude,
                                  imageBytes: imageBytes,
                                  boundingBox: _lastDetection?['box'] is Rect
                                      ? _lastDetection!['box'] as Rect
                                      : null,
                                );

                                if (!mounted) return;

                                if (success) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Detección guardada en el historial',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  setButtonState(() {
                                    isSaving = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No se pudo guardar la detección.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Guardando...'),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.save_outlined),
                                  SizedBox(width: 8),
                                  Text('Guardar en Historial'),
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isImageLoaded = _selectedImageBytes != null;
    final detectionBox = _lastDetection?['box'];
    final hasDetectionBox =
        _lastDetection != null && detectionBox is Rect && !detectionBox.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capturar Plaga'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          children: [
            Card(
              color: colorScheme.secondaryContainer,
              margin: const EdgeInsets.only(bottom: 24.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: colorScheme.onSecondaryContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Asegúrate de enfocar bien la hoja y tener buena luz.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isImageLoaded
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: isImageLoaded
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                          ),
                          if (hasDetectionBox)
                            CustomPaint(
                              painter: _DetectionBoxPainter(
                                detection: _lastDetection!,
                              ),
                            ),
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 80,
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se ha seleccionado imagen',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Cargar de Galería'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Tomar Foto'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: isImageLoaded && !_isAnalyzing ? _analyzeCrop : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                  disabledForegroundColor: colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 24,
                      color: isImageLoaded && !_isAnalyzing
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isAnalyzing ? 'Analizando...' : 'Analizar Cultivo',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isImageLoaded && !_isAnalyzing
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetectionBoxPainter extends CustomPainter {
  const _DetectionBoxPainter({
    required this.detection,
  });

  final Map<String, dynamic> detection;

  @override
  void paint(Canvas canvas, Size size) {
    final box = detection['box'];
    if (box is! Rect || box.isEmpty) return;

    final confidence = detection['confianza'];
    final confidenceValue = confidence is num ? confidence.toDouble() : 0.0;
    final confidencePercent = (confidenceValue * 100).round();
    final pestName = detection['plaga']?.toString() ?? 'Plaga';
    final label = '$pestName - $confidencePercent%';

    final scaledBox = Rect.fromLTRB(
      box.left * size.width,
      box.top * size.height,
      box.right * size.width,
      box.bottom * size.height,
    );

    final fillPaint = Paint()
      ..color = Colors.green.withOpacity(0.16)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(scaledBox, fillPaint);
    canvas.drawRect(scaledBox, strokePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: (size.width - 16).clamp(0.0, size.width).toDouble());

    const labelPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 4);
    final labelWidth = textPainter.width + labelPadding.horizontal;
    final labelHeight = textPainter.height + labelPadding.vertical;
    final maxLabelLeft = (size.width - labelWidth).clamp(0.0, size.width);
    final maxLabelTop = (size.height - labelHeight).clamp(0.0, size.height);
    final labelLeft = scaledBox.left.clamp(0.0, maxLabelLeft);
    final labelTop = (scaledBox.top - labelHeight).clamp(0.0, maxLabelTop);
    final labelRect = Rect.fromLTWH(
      labelLeft.toDouble(),
      labelTop.toDouble(),
      labelWidth,
      labelHeight,
    );

    final labelPaint = Paint()..color = Colors.green;
    canvas.drawRect(labelRect, labelPaint);
    textPainter.paint(
      canvas,
      Offset(
        labelRect.left + labelPadding.left,
        labelRect.top + labelPadding.top,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DetectionBoxPainter oldDelegate) {
    return oldDelegate.detection != detection;
  }
}
