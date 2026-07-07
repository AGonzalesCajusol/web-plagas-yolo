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

  Widget _buildStatusChip({
    required BuildContext context,
    required String commonName,
    required double confidence,
  }) {
    const darkGreen = Color(0xFF1B5E20);
    const warningBackground = Color(0xFFFFF8E1);
    const riskBackground = Color(0xFFFFEBEE);

    final normalized = commonName.toLowerCase();
    final isHealthy = normalized.contains('sano') ||
        normalized.contains('saludable') ||
        normalized.contains('sin plaga');
    final isLowConfidence = confidence > 0 && confidence < 0.55;
    final isUnknown = normalized.contains('sin nombre') ||
        normalized.contains('sin dete') ||
        normalized.contains('no detect');

    final label = isHealthy
        ? 'Arroz sano'
        : isLowConfidence
            ? 'Baja confianza'
            : isUnknown
                ? 'Sin detección'
                : 'Plaga detectada';
    final backgroundColor = isHealthy
        ? const Color(0xFFE8F5E9)
        : isLowConfidence
            ? warningBackground
            : isUnknown
                ? const Color(0xFFF3F4F6)
                : riskBackground;
    final foregroundColor = isHealthy
        ? darkGreen
        : isLowConfidence
            ? const Color(0xFF8A5A00)
            : isUnknown
                ? const Color(0xFF4B5563)
                : const Color(0xFFC62828);
    final icon = isHealthy
        ? Icons.eco_outlined
        : isLowConfidence
            ? Icons.info_outline
            : isUnknown
                ? Icons.search_off_outlined
                : Icons.bug_report_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foregroundColor.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: foregroundColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview({
    required BuildContext context,
    required String imagePath,
    required File imageFile,
    required double? boxLeft,
    required double? boxTop,
    required double? boxRight,
    required double? boxBottom,
    required String commonName,
    required double confidence,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textSecondary = Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 320,
          width: double.infinity,
          child: imagePath.isNotEmpty && imageFile.existsSync()
              ? FutureBuilder<Size?>(
                  future: _readImageSize(imageFile),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ColoredBox(
                        color: Color(0xFFE8F5E9),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      );
                    }

                    final imageSize = snapshot.data;
                    if (imageSize == null) {
                      return const _ImagePlaceholder();
                    }

                    return ColoredBox(
                      color: const Color(0xFFF6FAF6),
                      child: Center(
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
                      ),
                    );
                  },
                )
              : Container(
                  color: const Color(0xFFE8F5E9),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 56,
                          color: primaryGreen,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Imagen no disponible',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: textSecondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required BuildContext context,
    required String commonName,
    required String scientificName,
    required double confidence,
    required int confidencePercent,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(22),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
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
                      'Resultado',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      commonName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w900,
                                height: 1.12,
                                letterSpacing: 0,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            scientificName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildStatusChip(
                context: context,
                commonName: commonName,
                confidence: confidence,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Confianza $confidencePercent%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: darkGreen,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: const Color(0xFFE8F5E9),
              valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String date,
    required String parcelName,
    required String locationText,
    required String locationOriginText,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);

    return Container(
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
            'Información de la detección',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkGreen = Color(0xFF1B5E20);
    const lightGreen = Color(0xFFE8F5E9);
    const backgroundColor = Color(0xFFF6FAF6);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Detalle de detección'),
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
                          color: darkGreen.withOpacity(0.08),
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
                              Icons.eco_outlined,
                              color: darkGreen,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detalle de detección',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Información completa del análisis',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
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
                    _buildImagePreview(
                      context: context,
                      imagePath: imagePath,
                      imageFile: imageFile,
                      boxLeft: boxLeft,
                      boxTop: boxTop,
                      boxRight: boxRight,
                      boxBottom: boxBottom,
                      commonName: commonName,
                      confidence: confidence,
                    ),
                    const SizedBox(height: 18),
                    _buildResultCard(
                      context: context,
                      commonName: commonName,
                      scientificName: scientificName,
                      confidence: confidence,
                      confidencePercent: confidencePercent,
                    ),
                    const SizedBox(height: 18),
                    _buildInfoCard(
                      context: context,
                      date: date,
                      parcelName: parcelName,
                      locationText: locationText,
                      locationOriginText: locationOriginText,
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

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    const textSecondary = Color(0xFF6B7280);

    return Container(
      color: const Color(0xFFE8F5E9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: 56,
              color: primaryGreen,
            ),
            const SizedBox(height: 10),
            Text(
              'No se pudo cargar la imagen',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
            ),
          ],
        ),
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
    const primaryGreen = Color(0xFF2E7D32);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 20,
            color: primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: 0,
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
      ..color = const Color(0xFF2E7D32)
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

    canvas.drawRect(labelRect, Paint()..color = const Color(0xFF2E7D32));
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
