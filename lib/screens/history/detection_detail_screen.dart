import 'dart:io';

import 'package:flutter/material.dart';

class DetectionDetailScreen extends StatelessWidget {
  const DetectionDetailScreen({
    super.key,
    required this.detection,
  });

  final Map<String, dynamic> detection;

  String _stringValue(String key, {String fallback = 'No disponible'}) {
    final value = detection[key]?.toString();
    if (value == null || value.trim().isEmpty) return fallback;
    return value;
  }

  double _doubleValue(String key) {
    final value = detection[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double? _nullableDoubleValue(String key) {
    final value = detection[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatLocation() {
    final latitude = _nullableDoubleValue('latitud');
    final longitude = _nullableDoubleValue('longitud');

    if (latitude == null || longitude == null) {
      return 'Ubicación no disponible';
    }

    if (latitude == 0.0 && longitude == 0.0) {
      return 'Ubicación no disponible';
    }

    return 'Lat: ${latitude.toStringAsFixed(6)}, Lon: ${longitude.toStringAsFixed(6)}';
  }

  String _formatLocationOrigin() {
    final origin = detection['ubicacion_origen']?.toString();
    if (origin == null || origin.trim().isEmpty) {
      final latitude = _nullableDoubleValue('latitud');
      final longitude = _nullableDoubleValue('longitud');
      if (latitude == null ||
          longitude == null ||
          (latitude == 0.0 && longitude == 0.0)) {
        return 'Origen: no disponible';
      }
      return 'Origen no especificado';
    }

    switch (origin) {
      case 'gps':
        return 'GPS';
      case 'ultima_conocida':
        return 'Última ubicación conocida';
      case 'parcela':
        return 'Parcela';
      case 'manual':
        return 'Manual';
      case 'no_disponible':
        return 'No disponible';
      default:
        return 'Origen no especificado';
    }
  }

  Future<Size?> _readImageSize(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);

      return Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
    } catch (error) {
      debugPrint('No se pudo leer el tamaño de la imagen: $error');
      return null;
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Fecha no disponible';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final imagePath = _stringValue('ruta_imagen', fallback: '');
    final imageFile = File(imagePath);
    final commonName = _stringValue('nombre_comun');
    final scientificName = _stringValue(
      'nombre_cientifico',
      fallback: commonName,
    );
    final confidence = _doubleValue('confianza');
    final confidencePercent = (confidence * 100).round();
    final locationText = _formatLocation();
    final locationOriginText = _formatLocationOrigin();
    final parcelName = _stringValue(
      'nombre_parcela',
      fallback: 'Parcela no registrada',
    );
    final date = _formatDate(detection['fecha_hora']);
    final boxLeft = _nullableDoubleValue('box_left');
    final boxTop = _nullableDoubleValue('box_top');
    final boxRight = _nullableDoubleValue('box_right');
    final boxBottom = _nullableDoubleValue('box_bottom');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Detección'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              child: imagePath.isNotEmpty && imageFile.existsSync()
                  ? FutureBuilder<Size?>(
                      future: _readImageSize(imageFile),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final imageSize = snapshot.data;
                        if (imageSize == null) {
                          return Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        }

                        return Center(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: imageSize.width,
                              height: imageSize.height,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    imageFile,
                                    fit: BoxFit.fill,
                                  ),
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: BoundingBoxPainter(
                                        left: boxLeft,
                                        top: boxTop,
                                        right: boxRight,
                                        bottom: boxBottom,
                                        pestName: commonName,
                                        confidence: confidence,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 1,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commonName,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scientificName,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _DetailRow(
                        icon: Icons.schedule_outlined,
                        label: 'Fecha exacta',
                        value: date,
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        icon: Icons.landscape_outlined,
                        label: 'Parcela',
                        value: parcelName,
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        icon: Icons.analytics_outlined,
                        label: 'Confianza',
                        value: '$confidencePercent%',
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Ubicación',
                        value: locationText,
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        icon: Icons.my_location_outlined,
                        label: 'Origen de ubicación',
                        value: locationOriginText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 19,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  const BoundingBoxPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.pestName,
    required this.confidence,
  });

  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final String pestName;
  final double confidence;

  @override
  void paint(Canvas canvas, Size size) {
    if (left == null || top == null || right == null || bottom == null) {
      return;
    }

    final scaledBox = Rect.fromLTRB(
      left!.clamp(0.0, 1.0).toDouble() * size.width,
      top!.clamp(0.0, 1.0).toDouble() * size.height,
      right!.clamp(0.0, 1.0).toDouble() * size.width,
      bottom!.clamp(0.0, 1.0).toDouble() * size.height,
    );

    if (scaledBox.isEmpty) return;

    final strokePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(scaledBox, strokePaint);

    final confidencePercent = (confidence * 100).round();
    final label = '$pestName - $confidencePercent%';
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

    canvas.drawRect(labelRect, Paint()..color = Colors.green);
    textPainter.paint(
      canvas,
      Offset(
        labelRect.left + labelPadding.left,
        labelRect.top + labelPadding.top,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.left != left ||
        oldDelegate.top != top ||
        oldDelegate.right != right ||
        oldDelegate.bottom != bottom ||
        oldDelegate.pestName != pestName ||
        oldDelegate.confidence != confidence;
  }
}
