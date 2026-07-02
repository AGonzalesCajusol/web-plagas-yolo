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

      // Permite que Flutter pinte el diálogo antes de iniciar la inferencia.
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
                  'Procesando predicción...\nEsto puede tardar unos segundos.',
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

  void _showResultBottomSheet(Map<String, dynamic> resultado) {
    final colorScheme = Theme.of(context).colorScheme;
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
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            final parcelaNombre = _nombreParcelaSeleccionada;
            final hasParcelaSeleccionada = _hasParcelaSeleccionada;
            final locationPreview =
                _selectedParcelaLocation() ?? _LocationData.unavailable();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      Text(
                        'Plaga detectada',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mensajeResultado,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${locationPreview.message}\n'
                              '${_formatLocation(locationPreview.latitude, locationPreview.longitude)}\n'
                              '${_formatLocationOrigin(locationPreview.origin)}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hasParcelaSeleccionada
                                  ? 'Parcela: $parcelaNombre'
                                  : 'No tienes parcelas registradas',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
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
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await _openCropsScreenFromCapture();
                              if (context.mounted) {
                                setBottomSheetState(() {});
                              }
                            },
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Agregar parcela'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: StatefulBuilder(
                          builder: (buttonContext, setButtonState) {
                            return FilledButton(
                              onPressed: isSaving || !hasParcelaSeleccionada
                                  ? null
                                  : () async {
                                      final imageBytes = _selectedImageBytes;
                                      if (imageBytes == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
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

                                      final success = await DetectionService()
                                          .saveDetection(
                                        userId: widget.userId,
                                        plagaNombre: plaga,
                                        confianza: confianzaValor,
                                        latitud: location.latitude,
                                        longitud: location.longitude,
                                        ubicacionOrigen: location.origin,
                                        imageBytes: imageBytes,
                                        cultivoId: _parcelaSeleccionadaId,
                                        boundingBox:
                                            _lastDetection?['box'] is Rect
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
                              child: isSaving
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
              ),
            );
          },
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
      body: SingleChildScrollView(
        child: Padding(
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
              if (_parcelas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _parcelaSeleccionadaId,
                    decoration: InputDecoration(
                      labelText: 'Parcela',
                      prefixIcon: const Icon(Icons.landscape),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: _parcelas.map((parcela) {
                      final id = parcela['id']?.toString() ?? '';
                      final nombre =
                          parcela['nombre_parcela']?.toString() ?? 'Sin nombre';

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
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Parcela',
                          prefixIcon: const Icon(Icons.landscape),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('No tienes parcelas registradas'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _openCropsScreenFromCapture,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Agregar parcela'),
                      ),
                    ],
                  ),
                ),
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.35,
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
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
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
              const SizedBox(height: 20),
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
                  onPressed:
                      isImageLoaded && !_isAnalyzing ? _analyzeCrop : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor:
                        colorScheme.surfaceContainerHighest,
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
      ..color = Colors.green.withValues(alpha: 0.16)
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
