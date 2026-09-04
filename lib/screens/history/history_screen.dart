import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/detection_service.dart';
import '../../services/report_service.dart';
import '../../utils/affectation_display_utils.dart';
import 'detection_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = DetectionService().getHistorialDetecciones(
      userId: widget.userId,
    );
  }

  void _reloadHistory() {
    setState(() {
      _historyFuture = DetectionService().getHistorialDetecciones(
        userId: widget.userId,
      );
    });
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Fecha no disponible';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatLocation(dynamic latitudeValue, dynamic longitudeValue) {
    final latitude = _nullableDouble(latitudeValue);
    final longitude = _nullableDouble(longitudeValue);

    if (latitude == null || longitude == null) {
      return 'Ubicación no disponible';
    }

    if (latitude == 0.0 && longitude == 0.0) {
      return 'Ubicación no disponible';
    }

    return 'Lat: ${latitude.toStringAsFixed(6)}, Lon: ${longitude.toStringAsFixed(6)}';
  }

  String _formatLocationOrigin(
    dynamic originValue,
    dynamic latitudeValue,
    dynamic longitudeValue,
  ) {
    final origin = originValue?.toString();
    if (origin == null || origin.trim().isEmpty) {
      final latitude = _nullableDouble(latitudeValue);
      final longitude = _nullableDouble(longitudeValue);
      if (latitude == null ||
          longitude == null ||
          (latitude == 0.0 && longitude == 0.0)) {
        return 'Origen: no disponible';
      }
      return 'Origen no especificado';
    }

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

  Future<void> _exportPdf() async {
    var loadingDialogShown = false;
    try {
      final detecciones = await _historyFuture;
      if (detecciones.isEmpty || !mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 18),
                Expanded(
                  child: Text('Generando reporte PDF...'),
                ),
              ],
            ),
          );
        },
      );
      loadingDialogShown = true;

      final path = await ReportService().generateFullReport(detecciones);

      if (!mounted) return;
      if (loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (path.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path)],
            text: 'Reporte de Plagas de Arroz',
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el reporte PDF: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteDetection(String detectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Eliminar detección'),
          content: const Text('¿Deseas eliminar esta detección?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final deleted = await DetectionService().deleteDetection(
      userId: widget.userId,
      detectionId: detectionId,
    );

    if (!mounted) return;

    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Detección eliminada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
      _reloadHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar la detección seleccionada.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Limpiar historial'),
          content: const Text(
            'Esta acción eliminará todas tus detecciones registradas. Tus parcelas no serán eliminadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Limpiar historial'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final deletedCount = await DetectionService().clearUserDetections(
      userId: widget.userId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deletedCount == 1
              ? 'Se eliminó 1 detección.'
              : 'Se eliminaron $deletedCount detecciones.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    _reloadHistory();
  }

  Widget _buildStatusChip({
    required BuildContext context,
    required String nombrePlaga,
    required double confianza,
  }) {
    const darkGreen = Color(0xFF1B5E20);
    const warningBackground = Color(0xFFFFF8E1);
    const riskBackground = Color(0xFFFFEBEE);

    final normalized = nombrePlaga.toLowerCase();
    final isHealthy = normalized.contains('sano') ||
        normalized.contains('saludable') ||
        normalized.contains('sin plaga');
    final isLowConfidence = confianza > 0 && confianza < 0.55;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            size: 14,
            color: foregroundColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    bool showProgress = false,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  size: 34,
                  color: iconColor ?? primaryGreen,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                      height: 1.4,
                      letterSpacing: 0,
                    ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 20),
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAffectationChip({
    required BuildContext context,
    required String? level,
  }) {
    final normalizedLevel = level?.trim().toUpperCase();
    final foregroundColor = switch (normalizedLevel) {
      'BAJO' => const Color(0xFF2E7D32),
      'MEDIO' => const Color(0xFF8A5A00),
      'ALTO' => const Color(0xFFC62828),
      'NO_EVALUADO' => const Color(0xFF6B7280),
      _ => const Color(0xFF64748B),
    };
    final backgroundColor = switch (normalizedLevel) {
      'BAJO' => const Color(0xFFE8F5E9),
      'MEDIO' => const Color(0xFFFFF8E1),
      'ALTO' => const Color(0xFFFFEBEE),
      _ => const Color(0xFFF3F4F6),
    };
    final label = AffectationDisplayUtils.levelLabel(level).toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_outlined, size: 14, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            'Nivel $label',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader({
    required BuildContext context,
    required int total,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Container(
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
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.history,
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
                    'Historial',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Consulta tus detecciones registradas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textSecondary,
                          height: 1.35,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                total == 1 ? '1 registro' : '$total registros',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: darkGreen,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionCard({
    required BuildContext context,
    required Map<String, dynamic> deteccion,
  }) {
    const primaryGreen = Color(0xFF2E7D32);
    const darkGreen = Color(0xFF1B5E20);
    const textPrimary = Color(0xFF1F2933);
    const textSecondary = Color(0xFF6B7280);

    final detectionId = deteccion['id']?.toString() ?? '';
    final rutaImagen = deteccion['ruta_imagen']?.toString() ?? '';
    final nombrePlaga = deteccion['nombre_comun']?.toString() ?? 'Sin nombre';
    final confianza = _toDouble(deteccion['confianza']);
    final nivelAfectacion = deteccion['nivel_afectacion']?.toString();
    final ubicacion = _formatLocation(
      deteccion['latitud'],
      deteccion['longitud'],
    );
    final ubicacionOrigen = _formatLocationOrigin(
      deteccion['ubicacion_origen'],
      deteccion['latitud'],
      deteccion['longitud'],
    );
    final fecha = _formatDate(deteccion['fecha_hora']);
    final imageFile = File(rutaImagen);
    final nombreParcela =
        deteccion['nombre_parcela']?.toString() ?? 'Parcela no registrada';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetectionDetailScreen(
                detection: deteccion,
              ),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 94,
                  height: 112,
                  child: imageFile.existsSync()
                      ? Image.file(
                          imageFile,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Icon(
                            Icons.eco_outlined,
                            color: primaryGreen,
                            size: 34,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nombrePlaga,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w900,
                                  height: 1.18,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: darkGreen,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusChip(
                          context: context,
                          nombrePlaga: nombrePlaga,
                          confianza: confianza,
                        ),
                        _buildAffectationChip(
                          context: context,
                          level: nivelAfectacion,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            fecha,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: textSecondary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Parcela: $nombreParcela',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: confianza.clamp(0.0, 1.0).toDouble(),
                              minHeight: 7,
                              backgroundColor: const Color(0xFFE8F5E9),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                primaryGreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(confianza * 100).round()}%',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: primaryGreen,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Confianza IA: ${(confianza * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: primaryGreen,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$ubicacion\n$ubicacionOrigen',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: textSecondary,
                                      height: 1.35,
                                      letterSpacing: 0,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Eliminar detección',
                icon: const Icon(Icons.delete_outline),
                color: Theme.of(context).colorScheme.error,
                onPressed: detectionId.isEmpty
                    ? null
                    : () => _confirmDeleteDetection(detectionId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkGreen = Color(0xFF1B5E20);
    const lightGreen = Color(0xFFE8F5E9);
    const backgroundColor = Color(0xFFF6FAF6);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Historial'),
        centerTitle: true,
        backgroundColor: lightGreen,
        elevation: 0,
        foregroundColor: darkGreen,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearHistory();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'clear',
                child: Text('Limpiar historial'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Exportar PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportPdf,
          ),
        ],
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children: [
                    _buildHistoryHeader(
                      context: context,
                      total: 0,
                    ),
                    Expanded(
                      child: _buildStateCard(
                        context: context,
                        icon: Icons.history,
                        title: 'Cargando historial',
                        subtitle:
                            'Estamos preparando tus detecciones registradas.',
                        showProgress: true,
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Column(
                  children: [
                    _buildHistoryHeader(
                      context: context,
                      total: 0,
                    ),
                    Expanded(
                      child: _buildStateCard(
                        context: context,
                        icon: Icons.error_outline,
                        title: 'No se pudo cargar el historial',
                        subtitle:
                            'Intenta volver a abrir esta pantalla en unos momentos.',
                        iconColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                );
              }

              final detecciones = snapshot.data ?? [];
              if (detecciones.isEmpty) {
                return Column(
                  children: [
                    _buildHistoryHeader(
                      context: context,
                      total: 0,
                    ),
                    Expanded(
                      child: _buildStateCard(
                        context: context,
                        icon: Icons.eco_outlined,
                        title: 'Aún no hay detecciones',
                        subtitle:
                            'Cuando analices una imagen, aparecerá aquí tu historial.',
                      ),
                    ),
                  ],
                );
              }

              return ListView.builder(
                padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: detecciones.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHistoryHeader(
                      context: context,
                      total: detecciones.length,
                    );
                  }

                  final deteccion = detecciones[index - 1];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _buildDetectionCard(
                      context: context,
                      deteccion: deteccion,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
