import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  AIService._();

  static final AIService instance = AIService._();
  static const int _inputSize = 640;
  static const double _confidenceThreshold = 0.30;
  static const double _possibleThreshold = 0.50;
  static const double _confirmedThreshold = 0.70;
  static const double _iouThreshold = 0.45;
  static const String _modelPath =
      'assets/models/detector_yolo_plagas_v1_float32.tflite';
  static const String _classNamesPath =
      'assets/models/class_names_detector.txt';
  static const List<String> _defaultLabels = [
    'ANUBLO',
    'HOJA_BLANCA',
    'SOGATA',
  ];

  Interpreter? _interpreter;
  List<String> _labels = _defaultLabels;

  bool get isModelLoaded => _interpreter != null;

  Future<void> loadModel() async {
    if (_interpreter != null) return;

    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _labels = await _loadLabels();
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
        'La imagen no puede estar vacia.',
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

    debugPrint('[YOLO] input shape esperado: [1,3,640,640]');
    debugPrint('[YOLO] output shape esperado: [1,7,8400]');

    _interpreter!.run(inputTensor, output);

    final analysis = _analyzeDetections(output, outputShape);
    final detection = analysis.detection;
    if (detection == null) {
      _logYoloResult(
        detection: analysis.topRawDetection,
        decision: 'NO_DETECTION',
      );

      return {
        'plaga': 'Arroz sin plaga visible',
        'confianza': 0.0,
        'box': Rect.zero,
        'decision': 'NO_DETECTION',
        'mensaje': 'Arroz sin plaga visible',
        'scores': _scoresMap(analysis.topRawDetection),
      };
    }

    final plaga = _labels[detection.classId];
    final decision = _decisionForScore(detection.score);
    final mensaje = _messageForDecision(
      decision: decision,
      plaga: plaga,
    );

    _logYoloResult(
      detection: detection,
      decision: decision,
    );

    return {
      'plaga': plaga,
      'confianza': detection.score,
      'box': detection.boundingBox,
      'decision': decision,
      'mensaje': mensaje,
      'scores': _scoresMap(detection),
    };
  }

  Future<List<String>> _loadLabels() async {
    try {
      final content = await rootBundle.loadString(_classNamesPath);
      final labels = content
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (labels.length >= 3) {
        return labels.take(3).toList();
      }
    } catch (error, stackTrace) {
      log(
        'No se pudo leer class_names_detector.txt; se usaran clases por defecto.',
        name: 'AIService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return _defaultLabels;
  }

  dynamic _imageToFloat32Tensor(img.Image image) {
    final inputBuffer = Float32List(1 * 3 * _inputSize * _inputSize);
    var bufferIndex = 0;

    for (var channel = 0; channel < 3; channel++) {
      for (var y = 0; y < _inputSize; y++) {
        for (var x = 0; x < _inputSize; x++) {
          final pixel = image.getPixel(x, y);
          final value = switch (channel) {
            0 => pixel.r,
            1 => pixel.g,
            _ => pixel.b,
          };

          inputBuffer[bufferIndex++] = value / 255.0;
        }
      }
    }

    return inputBuffer.reshape<double>([1, 3, _inputSize, _inputSize]);
  }

  dynamic _createOutputBuffer(List<int> shape) {
    final totalSize =
        shape.fold<int>(1, (total, dimension) => total * dimension);
    return List<double>.filled(totalSize, 0.0).reshape<double>(shape);
  }

  _YoloAnalysis _analyzeDetections(dynamic output, List<int> outputShape) {
    if (outputShape.length != 3 ||
        outputShape[0] != 1 ||
        outputShape[1] != 7 ||
        outputShape[2] != 8400) {
      throw StateError('Forma de salida YOLO no soportada: $outputShape');
    }

    final rawOutput = output[0] as List;
    const rawPredictionCount = 8400;
    final thresholdDetections = <_Detection>[];
    _Detection? topRawDetection;

    debugPrint('[YOLO] total raw predictions: $rawPredictionCount');

    for (var predictionIndex = 0;
        predictionIndex < rawPredictionCount;
        predictionIndex++) {
      final anubloScore =
          _valueAt(rawOutput, 4, predictionIndex).clamp(0.0, 1.0).toDouble();
      final hojaBlancaScore =
          _valueAt(rawOutput, 5, predictionIndex).clamp(0.0, 1.0).toDouble();
      final sogataScore =
          _valueAt(rawOutput, 6, predictionIndex).clamp(0.0, 1.0).toDouble();

      var classId = 0;
      var score = anubloScore;
      if (hojaBlancaScore > score) {
        classId = 1;
        score = hojaBlancaScore;
      }
      if (sogataScore > score) {
        classId = 2;
        score = sogataScore;
      }

      final detection = _Detection(
        classId: classId,
        score: score,
        boundingBox: _boundingBoxFromYoloValues(
          cx: _valueAt(rawOutput, 0, predictionIndex),
          cy: _valueAt(rawOutput, 1, predictionIndex),
          width: _valueAt(rawOutput, 2, predictionIndex),
          height: _valueAt(rawOutput, 3, predictionIndex),
        ),
        classScores: [anubloScore, hojaBlancaScore, sogataScore],
      );

      if (topRawDetection == null || detection.score > topRawDetection.score) {
        topRawDetection = detection;
      }

      if (score >= _confidenceThreshold) {
        thresholdDetections.add(detection);
      }
    }

    debugPrint(
      '[YOLO] detections sobre threshold: ${thresholdDetections.length}',
    );

    final nmsDetections = _applyNms(thresholdDetections);
    final topDetection =
        nmsDetections.isNotEmpty ? nmsDetections.first : topRawDetection;

    if (topDetection != null) {
      debugPrint('[YOLO] top1 classId: ${topDetection.classId}');
      debugPrint('[YOLO] top1 className: ${_labels[topDetection.classId]}');
      debugPrint(
        '[YOLO] top1 score: ${topDetection.score.toStringAsFixed(4)}',
      );
      debugPrint(
        '[YOLO] top scores => ANUBLO: ${topDetection.classScores[0].toStringAsFixed(4)}, '
        'HOJA_BLANCA: ${topDetection.classScores[1].toStringAsFixed(4)}, '
        'SOGATA: ${topDetection.classScores[2].toStringAsFixed(4)}',
      );
    }

    return _YoloAnalysis(
      detection: nmsDetections.isEmpty ? null : nmsDetections.first,
      topRawDetection: topRawDetection,
    );
  }

  String _decisionForScore(double score) {
    if (score < _possibleThreshold) return 'LOW_CONFIDENCE';
    if (score < _confirmedThreshold) return 'POSSIBLE';
    return 'CONFIRMED';
  }

  String _messageForDecision({
    required String decision,
    required String plaga,
  }) {
    return switch (decision) {
      'LOW_CONFIDENCE' =>
        'No se detectó una plaga con suficiente confianza. '
            'Tome otra foto con mejor enfoque.',
      'POSSIBLE' =>
        'Posible $plaga detectada con confianza moderada. '
            'Tome otra foto para confirmar.',
      _ => '$plaga detectada',
    };
  }

  Map<String, double> _scoresMap(_Detection? detection) {
    if (detection == null) return const {};

    return {
      'ANUBLO': detection.classScores[0],
      'HOJA_BLANCA': detection.classScores[1],
      'SOGATA': detection.classScores[2],
    };
  }

  void _logYoloResult({
    required _Detection? detection,
    required String decision,
  }) {
    final topClass = detection == null ? 'NONE' : _labels[detection.classId];
    final topScore = detection?.score ?? 0.0;

    debugPrint('[YOLO Result] topClass=$topClass');
    debugPrint('[YOLO Result] topScore=${topScore.toStringAsFixed(4)}');
    debugPrint('[YOLO Result] decision=$decision');

    if (detection != null) {
      debugPrint(
        '[YOLO Scores] ANUBLO=${detection.classScores[0].toStringAsFixed(4)}',
      );
      debugPrint(
        '[YOLO Scores] HOJA_BLANCA=${detection.classScores[1].toStringAsFixed(4)}',
      );
      debugPrint(
        '[YOLO Scores] SOGATA=${detection.classScores[2].toStringAsFixed(4)}',
      );
    }
  }

  double _valueAt(List rawOutput, int featureIndex, int predictionIndex) {
    return (rawOutput[featureIndex][predictionIndex] as num).toDouble();
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

  List<_Detection> _applyNms(List<_Detection> detections) {
    final sorted = [...detections]..sort((a, b) => b.score.compareTo(a.score));
    final selected = <_Detection>[];

    for (final detection in sorted) {
      final shouldSuppress = selected.any(
        (selectedDetection) =>
            selectedDetection.classId == detection.classId &&
            _iou(selectedDetection.boundingBox, detection.boundingBox) >
                _iouThreshold,
      );

      if (!shouldSuppress) {
        selected.add(detection);
      }
    }

    return selected;
  }

  double _iou(Rect a, Rect b) {
    final intersectionLeft = a.left > b.left ? a.left : b.left;
    final intersectionTop = a.top > b.top ? a.top : b.top;
    final intersectionRight = a.right < b.right ? a.right : b.right;
    final intersectionBottom = a.bottom < b.bottom ? a.bottom : b.bottom;
    final intersectionWidth =
        (intersectionRight - intersectionLeft).clamp(0.0, 1.0).toDouble();
    final intersectionHeight =
        (intersectionBottom - intersectionTop).clamp(0.0, 1.0).toDouble();
    final intersectionArea = intersectionWidth * intersectionHeight;

    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final unionArea = areaA + areaB - intersectionArea;

    if (unionArea <= 0) return 0.0;
    return intersectionArea / unionArea;
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
    required this.classScores,
  });

  final int classId;
  final double score;
  final Rect boundingBox;
  final List<double> classScores;
}

class _YoloAnalysis {
  const _YoloAnalysis({
    required this.detection,
    required this.topRawDetection,
  });

  final _Detection? detection;
  final _Detection? topRawDetection;
}
