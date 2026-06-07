import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/detection_service.dart';
import '../../services/report_service.dart';
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
  late final Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = DetectionService().getHistorialDetecciones(
      userId: widget.userId,
    );
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
          return const AlertDialog(
            content: Row(
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
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Reporte de Plagas de Arroz',
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Detecciones'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Exportar PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No se pudo cargar el historial',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final detecciones = snapshot.data ?? [];
          if (detecciones.isEmpty) {
            return Center(
              child: Text(
                'No hay detecciones guardadas',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: detecciones.length,
            itemBuilder: (context, index) {
              final deteccion = detecciones[index];
              final rutaImagen = deteccion['ruta_imagen']?.toString() ?? '';
              final nombrePlaga =
                  deteccion['nombre_comun']?.toString() ?? 'Sin nombre';
              final confianza = _toDouble(deteccion['confianza']);
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
              final nombreParcela = deteccion['nombre_parcela']?.toString() ??
                  'Parcela no registrada';

              return Card(
                elevation: 1,
                color: colorScheme.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 92,
                            height: 92,
                            child: imageFile.existsSync()
                                ? Image.file(
                                    imageFile,
                                    fit: BoxFit.cover,
                                  )
                                : ColoredBox(
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombrePlaga,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                fecha,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Parcela: $nombreParcela',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Confianza: ${(confianza * 100).round()}%',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '$ubicacion\n$ubicacionOrigen',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
      ),
    );
  }
}
