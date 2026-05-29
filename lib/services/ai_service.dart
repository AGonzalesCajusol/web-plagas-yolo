import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  AIService._();

  static final AIService instance = AIService._();
  static const int _inputSize = 640;
  static const double _confidenceThreshold = 0.1; // Igual que en tu Colab
  static const List<String> _labels = [
    'Añublo bacteriano',
    'Hoja blanca',
    'Sogata',
  ];

  Interpreter? _interpreter;

  bool get isModelLoaded => _interpreter != null;

  Future<void> loadModel() async {
    if (_interpreter != null) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float32.tflite',
      );
      log('Modelo TFLite cargado correctamente.', name: 'AIService');
    } catch (error, stackTrace) {
      _interpreter = null;
      log(
        'Error al cargar el modelo TFLite.',
        name: 'AIService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeImage(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError.value(
        imageBytes,
        'imageBytes',
        'La imagen no puede estar vacía.',
      );
    }

    if (_interpreter == null) {
      await loadModel();
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

    final inputTensor = _imageToFloat32Tensor(resizedImage);
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final output = _createOutputBuffer(outputShape);

    _interpreter!.run(inputTensor, output);

    final detection = _findBestDetection(output, outputShape);
    if (detection == null) {
      return {
        'plaga': 'Sano',
        'confianza': 1.0,
        'box': Rect.zero,
      };
    }

    return {
      'plaga': _labels[detection.classId],
      'confianza': detection.score,
      'box': detection.boundingBox,
    };
  }

  dynamic _imageToFloat32Tensor(img.Image image) {
    final inputBuffer = Float32List(1 * _inputSize * _inputSize * 3);
    var bufferIndex = 0;

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        inputBuffer[bufferIndex++] = pixel.r / 255.0;
        inputBuffer[bufferIndex++] = pixel.g / 255.0;
        inputBuffer[bufferIndex++] = pixel.b / 255.0;
      }
    }

    return inputBuffer.reshape<double>([1, _inputSize, _inputSize, 3]);
  }

  dynamic _createOutputBuffer(List<int> shape) {
    final totalSize = shape.fold<int>(1, (total, dimension) => total * dimension);
    return List<double>.filled(totalSize, 0.0).reshape<double>(shape);
  }

  _Detection? _findBestDetection(dynamic output, List<int> outputShape) {
    if (outputShape.length != 3 || outputShape.first != 1) {
      throw StateError('Forma de salida YOLO no soportada: $outputShape');
    }

    final rawOutput = output[0] as List;
    final firstDimension = outputShape[1];
    final secondDimension = outputShape[2];

    if (firstDimension <= secondDimension) {
      return _findBestDetectionFromFeaturesFirst(
        rawOutput,
        featureCount: firstDimension,
        boxCount: secondDimension,
      );
    }

    return _findBestDetectionFromBoxesFirst(
      rawOutput,
      boxCount: firstDimension,
      featureCount: secondDimension,
    );
  }

  _Detection? _findBestDetectionFromFeaturesFirst(
    List rawOutput, {
    required int featureCount,
    required int boxCount,
  }) {
    final classStart = _classStartIndex(featureCount);
    _Detection? bestDetection;

    for (var boxIndex = 0; boxIndex < boxCount; boxIndex++) {
      final detection = _bestClassForBox(
        featureCount: featureCount,
        classStart: classStart,
        valueAt: (featureIndex) =>
            (rawOutput[featureIndex][boxIndex] as num).toDouble(),
      );

      if (detection != null &&
          (bestDetection == null || detection.score > bestDetection.score)) {
        bestDetection = detection;
      }
    }

    return _passesThreshold(bestDetection) ? bestDetection : null;
  }

  _Detection? _findBestDetectionFromBoxesFirst(
    List rawOutput, {
    required int boxCount,
    required int featureCount,
  }) {
    final classStart = _classStartIndex(featureCount);
    _Detection? bestDetection;

    for (var boxIndex = 0; boxIndex < boxCount; boxIndex++) {
      final box = rawOutput[boxIndex] as List;
      final detection = _bestClassForBox(
        featureCount: featureCount,
        classStart: classStart,
        valueAt: (featureIndex) => (box[featureIndex] as num).toDouble(),
      );

      if (detection != null &&
          (bestDetection == null || detection.score > bestDetection.score)) {
        bestDetection = detection;
      }
    }

    return _passesThreshold(bestDetection) ? bestDetection : null;
  }

  int _classStartIndex(int featureCount) {
    if (featureCount >= _labels.length + 5) {
      return 5;
    }

    return 4;
  }

  _Detection? _bestClassForBox({
    required int featureCount,
    required int classStart,
    required double Function(int featureIndex) valueAt,
  }) {
    _Detection? bestDetection;
    final objectness =
        (classStart == 5 ? valueAt(4) : 1.0).clamp(0.0, 1.0).toDouble();
    final boundingBox = _boundingBoxFromYoloValues(
      cx: valueAt(0),
      cy: valueAt(1),
      width: valueAt(2),
      height: valueAt(3),
    );

    for (var classId = 0; classId < _labels.length; classId++) {
      final featureIndex = classStart + classId;
      if (featureIndex >= featureCount) break;

      final classScore = valueAt(featureIndex).clamp(0.0, 1.0).toDouble();
      final score = objectness * classScore;

      if (bestDetection == null || score > bestDetection.score) {
        bestDetection = _Detection(
          classId: classId,
          score: score,
          boundingBox: boundingBox,
        );
      }
    }

    return bestDetection;
  }

  Rect _boundingBoxFromYoloValues({
    required double cx,
    required double cy,
    required double width,
    required double height,
  }) {
    final normalizedCx = _normalizeCoordinate(cx);
    final normalizedCy = _normalizeCoordinate(cy);
    final normalizedWidth = _normalizeCoordinate(width);
    final normalizedHeight = _normalizeCoordinate(height);

    final left = (normalizedCx - normalizedWidth / 2).clamp(0.0, 1.0);
    final top = (normalizedCy - normalizedHeight / 2).clamp(0.0, 1.0);
    final right = (normalizedCx + normalizedWidth / 2).clamp(0.0, 1.0);
    final bottom = (normalizedCy + normalizedHeight / 2).clamp(0.0, 1.0);

    return Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );
  }

  double _normalizeCoordinate(double value) {
    final normalized = value.abs() > 1.0 ? value / _inputSize : value;
    return normalized.clamp(0.0, 1.0).toDouble();
  }

  bool _passesThreshold(_Detection? detection) {
    return detection != null && detection.score > _confidenceThreshold;
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}

class _Detection {
  const _Detection({
    required this.classId,
    required this.score,
    required this.boundingBox,
  });

  final int classId;
  final double score;
  final Rect boundingBox;
}
