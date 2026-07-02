import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class RiceClassifierService {
  RiceClassifierService._();

  static final RiceClassifierService instance = RiceClassifierService._();
  static const double riceSafeThreshold = 0.30;
  static const double noRiceThreshold = 0.50;

  static const int _inputSize = 224;
  static const String _modelPath =
      'assets/models/clasificador_arroz_no_arroz_v2_dynamic_range.tflite';
  static const String _classNamesPath =
      'assets/models/class_names_clasificador_v2.txt';

  Interpreter? _interpreter;
  List<String> _classNames = const ['arroz', 'no_arroz'];

  bool get isModelLoaded => _interpreter != null;

  Future<void> load() async {
    if (_interpreter != null) return;

    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _classNames = await _loadClassNames();

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('RiceClassifier input tensor shape: $inputShape');
      debugPrint('RiceClassifier output tensor shape: $outputShape');

      log(
        'Clasificador arroz/no_arroz cargado correctamente.',
        name: 'RiceClassifierService',
      );
    } catch (error, stackTrace) {
      _interpreter = null;
      log(
        'Error al cargar el clasificador arroz/no_arroz.',
        name: 'RiceClassifierService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> loadModel() => load();

  Future<RiceClassifierResult> classifyImageFile(File imageFile) async {
    if (!await imageFile.exists()) {
      throw ArgumentError.value(
        imageFile.path,
        'imageFile',
        'El archivo de imagen no existe.',
      );
    }

    final imageBytes = await imageFile.readAsBytes();
    return classifyImage(imageBytes);
  }

  Future<RiceClassifierResult> classifyImage(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError.value(
        imageBytes,
        'imageBytes',
        'La imagen no puede estar vacia.',
      );
    }

    if (_interpreter == null) {
      await load();
    }

    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw ArgumentError.value(
        imageBytes,
        'imageBytes',
        'No se pudo decodificar la imagen.',
      );
    }

    final resizedImage = img.copyResize(
      decodedImage,
      width: _inputSize,
      height: _inputSize,
    );

    final inputTensor = _imageToRawFloat32Tensor(resizedImage);
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final output = _createOutputBuffer(outputShape);

    _interpreter!.run(inputTensor, output);

    final scoreNoArroz =
        _readFirstOutputValue(output).clamp(0.0, 1.0).toDouble();
    final isRice = scoreNoArroz <= riceSafeThreshold;
    final isNoRice = scoreNoArroz >= noRiceThreshold;
    final label = isRice
        ? _classNames[0]
        : isNoRice
            ? _classNames[1]
            : 'dudosa';
    final confidence = isNoRice ? scoreNoArroz : 1.0 - scoreNoArroz;

    if (kDebugMode) {
      debugPrint('[Classifier V2] label=$label');
      debugPrint(
        '[Classifier V2] scoreNoArroz=${scoreNoArroz.toStringAsFixed(4)}',
      );
      debugPrint('[Classifier V2] isRice=$isRice');
      debugPrint('[Classifier V2] isNoRice=$isNoRice');
    }

    return RiceClassifierResult(
      isRice: isRice,
      isNoRice: isNoRice,
      label: label,
      scoreNoArroz: scoreNoArroz,
      confidence: confidence,
    );
  }

  Future<List<String>> _loadClassNames() async {
    try {
      final content = await rootBundle.loadString(_classNamesPath);
      final names = content
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (names.length >= 2) {
        return [names[0], names[1]];
      }
    } catch (error, stackTrace) {
      log(
        'No se pudo leer class_names_clasificador_v2.txt; se usaran clases por defecto.',
        name: 'RiceClassifierService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return const ['arroz', 'no_arroz'];
  }

  dynamic _imageToRawFloat32Tensor(img.Image image) {
    final inputBuffer = Float32List(1 * _inputSize * _inputSize * 3);
    var bufferIndex = 0;

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        inputBuffer[bufferIndex++] = pixel.r.toDouble();
        inputBuffer[bufferIndex++] = pixel.g.toDouble();
        inputBuffer[bufferIndex++] = pixel.b.toDouble();
      }
    }

    return inputBuffer.reshape<double>([1, _inputSize, _inputSize, 3]);
  }

  dynamic _createOutputBuffer(List<int> shape) {
    final totalSize =
        shape.fold<int>(1, (total, dimension) => total * dimension);
    return List<double>.filled(totalSize, 0.0).reshape<double>(shape);
  }

  double _readFirstOutputValue(dynamic output) {
    var value = output;
    while (value is List && value.isNotEmpty) {
      value = value.first;
    }

    if (value is num) return value.toDouble();

    throw StateError(
      'Salida del clasificador no soportada: ${value.runtimeType}',
    );
  }

  void close() {
    dispose();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

class RiceClassifierResult {
  const RiceClassifierResult({
    required this.isRice,
    required this.isNoRice,
    required this.label,
    required this.scoreNoArroz,
    required this.confidence,
  });

  final bool isRice;
  final bool isNoRice;
  final String label;
  final double scoreNoArroz;
  final double confidence;
}
