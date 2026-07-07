import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ai_service.dart';
import '../../services/crop_service.dart';
import '../../services/detection_service.dart';
import '../../services/rice_classifier_service.dart';
import '../crops/crops_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  static const double _riceSafeThreshold = 0.30;
  static const double _noRiceThreshold = 0.50;

  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  File? _selectedImageFile;
  Map<String, dynamic>? _lastDetection;
  List<Map<String, dynamic>> _parcelas = [];
  String? _parcelaSeleccionadaId;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadParcelas();
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

  Future<void> _loadParcelas({String? preferredCultivoId}) async {
    final parcelas = await CropService.instance.getCultivos(
      userId: widget.userId,
    );

    if (!mounted) return;
    setState(() {
      _parcelas = parcelas;
      final preferredStillExists = parcelas.any(
        (parcela) => parcela['id']?.toString() == preferredCultivoId,
      );
      if (preferredStillExists) {
        _parcelaSeleccionadaId = preferredCultivoId;
        return;
      }

      if (parcelas.isNotEmpty) {
        final selectedStillExists = parcelas.any(
          (parcela) => parcela['id']?.toString() == _parcelaSeleccionadaId,
        );
        if (!selectedStillExists) {
          _parcelaSeleccionadaId = parcelas.first['id']?.toString();
        }
      } else {
        _parcelaSeleccionadaId = null;
      }
    });
  }

  bool get _hasParcelaSeleccionada {
    final selectedId = _parcelaSeleccionadaId;
    if (selectedId == null || selectedId.trim().isEmpty) return false;

    return _parcelas.any((parcela) => parcela['id']?.toString() == selectedId);
  }

  String get _nombreParcelaSeleccionada {
    for (final parcela in _parcelas) {
      if (parcela['id']?.toString() == _parcelaSeleccionadaId) {
        return parcela['nombre_parcela']?.toString() ?? 'Sin nombre';
      }
    }

    return 'Parcela no seleccionada';
  }

  Future<void> _openCropsScreenFromCapture() async {
    final createdCultivoId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => CropsScreen(
          userId: widget.userId,
          returnOnCreate: true,
        ),
      ),
    );

    if (!mounted) return;
    await _loadParcelas(preferredCultivoId: createdCultivoId);
  }

  Future<void> _changeParcelaForPendingDetection(
    VoidCallback refreshBottomSheet,
  ) async {
    if (_parcelas.isEmpty) {
      await _openCropsScreenFromCapture();
      if (mounted) refreshBottomSheet();
      return;
    }

    final selectedCultivoId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Seleccionar parcela'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          children: [
            for (final parcela in _parcelas)
              ListTile(
                title: Text(
                  parcela['nombre_parcela']?.toString() ?? 'Sin nombre',
                ),
                trailing: parcela['id']?.toString() == _parcelaSeleccionadaId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(
                  dialogContext,
                  parcela['id']?.toString(),
                ),
              ),
            const Divider(height: 1),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, '__add_crop__'),
              child: const Row(
                children: [
                  Icon(Icons.add_location_alt_outlined),
                  SizedBox(width: 10),
                  Text('Agregar parcela'),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || selectedCultivoId == null) return;

    if (selectedCultivoId == '__add_crop__') {
      await _openCropsScreenFromCapture();
    } else {
      setState(() {
        _parcelaSeleccionadaId = selectedCultivoId;
      });
    }

    if (mounted) refreshBottomSheet();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageFile = File(image.path);
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

  Future<_LocationData> _resolveLocationForSave() async {
    final parcelaLocation = _selectedParcelaLocation();

    if (parcelaLocation != null) {
      return parcelaLocation;
    }

    return _LocationData.unavailable();
  }

  _LocationData? _selectedParcelaLocation() {
    for (final parcela in _parcelas) {
      if (parcela['id']?.toString() == _parcelaSeleccionadaId) {
        final rawCoordinates = parcela['coordenadas_sector']?.toString();
        final parsed = _parseCoordinates(rawCoordinates);

        if (parsed == null) {
          return null;
        }

        return _LocationData(
          latitude: parsed.$1,
          longitude: parsed.$2,
          origin: 'parcela',
          message: 'Ubicación tomada desde la parcela',
        );
      }
    }

    return null;
  }

  (double, double)? _parseCoordinates(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final text = value.trim();

    if (text.toLowerCase().contains('no disponible')) {
      return null;
    }

    final regex = RegExp(r'-?\d+(?:[.,]\d+)?');
    final matches = regex.allMatches(text).toList();

    if (matches.length < 2) {
      return null;
    }

    final latitudeText = matches[0].group(0)!.replaceAll(',', '.');
    final longitudeText = matches[1].group(0)!.replaceAll(',', '.');

    final latitude = double.tryParse(latitudeText);
    final longitude = double.tryParse(longitudeText);

    if (!_isValidCoordinates(latitude, longitude)) {
      return null;
    }

    return (latitude!, longitude!);
  }

  bool _isValidCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude == 0.0 && longitude == 0.0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  String _formatLocationOrigin(String origin) {
    switch (origin) {
      case 'gps':
        return 'Origen: GPS';
      case 'ultima_conocida':
        return 'Origen: última ubicación conocida';
      case 'parcela':
        return 'Origen: parcela';
      case 'manual':
        return 'Origen: manual';
      case 'no_disponible':
        return 'Origen: no disponible';
      default:
        return 'Origen no especificado';
    }
  }

  String _formatLocation(double? latitude, double? longitude) {
    if (!_isValidCoordinates(latitude, longitude)) {
      return 'Ubicación no disponible';
    }

    return 'Lat: ${latitude!.toStringAsFixed(6)}, Lon: ${longitude!.toStringAsFixed(6)}';
  }

  Future<void> _analyzeCrop() async {
    final selectedImageFile = _selectedImageFile;
    if (_selectedImageBytes == null ||
        selectedImageFile == null ||
        _isAnalyzing) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    var loadingDialogShown = false;

    try {
      if (!mounted) return;

      _showLoadingDialog();
      loadingDialogShown = true;

      await Future<void>.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      await RiceClassifierService.instance.load();
      final classifierResult =
          await RiceClassifierService.instance.classifyImageFile(
        selectedImageFile,
      );

      debugPrint('[Classifier V2] label=${classifierResult.label}');
      debugPrint(
        '[Classifier V2] scoreNoArroz=${classifierResult.scoreNoArroz.toStringAsFixed(4)}',
      );
      debugPrint('[Classifier V2] isRice=${classifierResult.isRice}');
      debugPrint('[Classifier V2] isNoRice=${classifierResult.isNoRice}');

      if (!mounted) return;

      final scoreNoArroz = classifierResult.scoreNoArroz;
      final isSafeRice = scoreNoArroz <= _riceSafeThreshold;
      final isNoRice = scoreNoArroz >= _noRiceThreshold;

      if (!isSafeRice) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }

        setState(() {
          _lastDetection = null;
        });

        if (isNoRice) {
          debugPrint('[Flow] No arroz, YOLO bloqueado');
          await _showNoRiceDialog();
        } else {
          debugPrint('[Flow] Imagen dudosa, YOLO bloqueado');
          await _showDoubtfulRiceDialog();
        }
        return;
      }

      debugPrint('[Flow] Arroz seguro, ejecutando YOLO');

      final resultado = await AIService.instance.analyzeImage(
        _selectedImageBytes!,
      );
      final yoloDecision = resultado['decision']?.toString() ?? '';
      final yoloMessage =
          resultado['mensaje']?.toString() ?? 'Resultado no disponible';

      if (!mounted) return;

      if (loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogShown = false;
      }

      if (yoloDecision == 'NO_DETECTION') {
        setState(() {
          _lastDetection = null;
        });

        await _showYoloMessageDialog(
          title: 'Arroz sin plaga visible',
          message: 'Arroz sin plaga visible',
        );
        return;
      }

      if (yoloDecision == 'LOW_CONFIDENCE') {
        setState(() {
          _lastDetection = null;
        });

        await _showYoloMessageDialog(
          title: 'Baja confianza',
          message: yoloMessage,
        );
        return;
      }

      if (yoloDecision == 'POSSIBLE') {
        setState(() {
          _lastDetection = null;
        });

        await _showYoloMessageDialog(
          title: 'Resultado dudoso',
          message: yoloMessage,
        );
        return;
      }

      setState(() {
        _lastDetection = resultado;
      });

      _showResultBottomSheet(resultado);
    } catch (error) {
      if (!mounted) return;

      if (loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogShown = false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo analizar la imagen: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _showNoRiceDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Imagen no válida'),
          content: const Text('No corresponde a cultivo de arroz'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDoubtfulRiceDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Imagen dudosa'),
          content: const Text(
            'No se pudo confirmar que la imagen sea arroz. Tome otra foto con mejor enfoque.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showYoloMessageDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: const Row(
            children: [
              CircularProgressIndicator(
                color: Color(0xFF2E7D32),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Procesando predicción...\nEsto puede tardar unos segundos.',
                  style: TextStyle(
                    color: Color(0xFF1F2933),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResultBottomSheet(Map<String, dynamic> resultado) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const lightGreen = Color(0xFFE8F5E9);
    const backgroundColor = Color(0xFFF6FAF6);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    final textTheme = Theme.of(context).textTheme;
    final plaga = resultado['plaga']?.toString() ?? 'Resultado desconocido';
    final mensajeResultado =
        resultado['mensaje']?.toString() ?? '$plaga detectada';
    final confianza = resultado['confianza'];
    final confianzaValor = confianza is num ? confianza.toDouble() : 0.0;
    final confianzaPorcentaje = (confianzaValor * 100).round();
    var isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            final parcelaNombre = _nombreParcelaSeleccionada;
            final hasParcelaSeleccionada = _hasParcelaSeleccionada;
            final locationPreview =
                _selectedParcelaLocation() ?? _LocationData.unavailable();

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  4,
                  22,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: primaryGreen.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(
                              Icons.eco_outlined,
                              color: primaryGreen,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Resultado de detección',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Revisa el análisis antes de guardarlo',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: textSecondary,
                                    height: 1.35,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: primaryGreen.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: darkGreen.withOpacity(0.07),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plaga detectada',
                            style: textTheme.labelLarge?.copyWith(
                              color: textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mensajeResultado,
                            style: textTheme.headlineSmall?.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: confianzaValor
                                        .clamp(0.0, 1.0)
                                        .toDouble(),
                                    minHeight: 9,
                                    color: primaryGreen,
                                    backgroundColor: lightGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                '$confianzaPorcentaje%',
                                style: textTheme.titleMedium?.copyWith(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: primaryGreen.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: primaryGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${locationPreview.message}\n'
                              '${_formatLocation(locationPreview.latitude, locationPreview.longitude)}\n'
                              '${_formatLocationOrigin(locationPreview.origin)}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: textSecondary,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: hasParcelaSeleccionada
                            ? Colors.white
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: hasParcelaSeleccionada
                              ? primaryGreen.withOpacity(0.08)
                              : const Color(0xFFC62828).withOpacity(0.14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hasParcelaSeleccionada
                                      ? 'Parcela: $parcelaNombre'
                                      : 'No tienes parcelas registradas',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: hasParcelaSeleccionada
                                        ? textPrimary
                                        : const Color(0xFFC62828),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              if (hasParcelaSeleccionada)
                                TextButton(
                                  onPressed: () =>
                                      _changeParcelaForPendingDetection(
                                    () => setBottomSheetState(() {}),
                                  ),
                                  child: const Text('Cambiar'),
                                ),
                            ],
                          ),
                          if (!hasParcelaSeleccionada) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Debe seleccionar o registrar una parcela antes de guardar la detección.',
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFC62828),
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () async {
                                await _openCropsScreenFromCapture();
                                if (context.mounted) {
                                  setBottomSheetState(() {});
                                }
                              },
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Agregar parcela'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    StatefulBuilder(
                      builder: (buttonContext, setButtonState) {
                        return ElevatedButton(
                          onPressed: isSaving || !hasParcelaSeleccionada
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

                                  final location =
                                      await _resolveLocationForSave();

                                  final success =
                                      await DetectionService().saveDetection(
                                    userId: widget.userId,
                                    plagaNombre: plaga,
                                    confianza: confianzaValor,
                                    latitud: location.latitude,
                                    longitud: location.longitude,
                                    ubicacionOrigen: location.origin,
                                    imageBytes: imageBytes,
                                    cultivoId: _parcelaSeleccionadaId,
                                    boundingBox: _lastDetection?['box'] is Rect
                                        ? _lastDetection!['box'] as Rect
                                        : null,
                                  );

                                  if (!mounted) return;

                                  if (success) {
                                    Navigator.pop(this.context);
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
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No se pudo guardar la detección.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                darkGreen.withOpacity(0.45),
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
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
                                    Text('Guardar en historial'),
                                  ],
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const lightGreen = Color(0xFFE8F5E9);
    const backgroundColor = Color(0xFFF6FAF6);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    final textTheme = Theme.of(context).textTheme;
    final bool isImageLoaded = _selectedImageBytes != null;
    final detectionBox = _lastDetection?['box'];
    final hasDetectionBox =
        _lastDetection != null && detectionBox is Rect && !detectionBox.isEmpty;
    final previewHeight =
        (MediaQuery.of(context).size.height * 0.36).clamp(260.0, 380.0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Capturar plaga'),
        centerTitle: true,
        backgroundColor: lightGreen,
        elevation: 0,
        foregroundColor: darkGreen,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lightGreen,
              backgroundColor,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: primaryGreen.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: darkGreen.withOpacity(0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(19),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: primaryGreen,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Analizar cultivo',
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Captura o selecciona una imagen de arroz',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: textSecondary,
                                    height: 1.35,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF8A5A00).withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: Color(0xFF8A5A00),
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              'Asegúrate de enfocar bien la hoja y tener buena luz.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF8A5A00),
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: primaryGreen.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: darkGreen.withOpacity(0.07),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: _parcelas.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              initialValue: _parcelaSeleccionadaId,
                              decoration: InputDecoration(
                                labelText: 'Parcela',
                                prefixIcon:
                                    const Icon(Icons.landscape_outlined),
                                filled: true,
                                fillColor: const Color(0xFFF8FBF8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: primaryGreen.withOpacity(0.12),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: primaryGreen,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                              items: _parcelas.map((parcela) {
                                final id = parcela['id']?.toString() ?? '';
                                final nombre =
                                    parcela['nombre_parcela']?.toString() ??
                                        'Sin nombre';

                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(nombre),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _parcelaSeleccionadaId = value;
                                });
                              },
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Parcela',
                                    prefixIcon: const Icon(
                                      Icons.landscape_outlined,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FBF8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color:
                                            primaryGreen.withOpacity(0.12),
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'No tienes parcelas registradas',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _openCropsScreenFromCapture,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: darkGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.add_location_alt_outlined,
                                  ),
                                  label: const Text('Agregar parcela'),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: isImageLoaded
                              ? primaryGreen.withOpacity(0.30)
                              : primaryGreen.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: darkGreen.withOpacity(0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width: double.infinity,
                          height: previewHeight.toDouble(),
                          child: isImageLoaded
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                      cacheWidth: 900,
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.edit_outlined,
                                              color: Colors.white,
                                              size: 23,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  color: lightGreen,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 86,
                                        height: 86,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.72),
                                          borderRadius:
                                              BorderRadius.circular(28),
                                        ),
                                        child: const Icon(
                                          Icons.photo_camera_outlined,
                                          size: 48,
                                          color: primaryGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No se ha seleccionado imagen',
                                        style: textTheme.titleMedium?.copyWith(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Usa la cámara o carga una foto desde galería.',
                                        textAlign: TextAlign.center,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: textSecondary,
                                          height: 1.35,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                color: primaryGreen.withOpacity(0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galería'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _takePhoto,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Tomar foto'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed:
                            isImageLoaded && !_isAnalyzing ? _analyzeCrop : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: darkGreen.withOpacity(0.35),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.psychology_outlined, size: 24),
                        label: Text(
                          _isAnalyzing ? 'Analizando...' : 'Analizar cultivo',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      ..color = const Color(0xFF2E7D32).withOpacity(0.16)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF2E7D32)
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

    final labelPaint = Paint()..color = const Color(0xFF2E7D32);
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

class _LocationData {
  const _LocationData({
    required this.latitude,
    required this.longitude,
    required this.origin,
    required this.message,
  });

  factory _LocationData.unavailable() {
    return const _LocationData(
      latitude: null,
      longitude: null,
      origin: 'no_disponible',
      message: 'Ubicación no disponible',
    );
  }

  final double? latitude;
  final double? longitude;
  final String origin;
  final String message;
}
