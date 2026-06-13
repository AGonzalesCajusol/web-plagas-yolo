import 'dart:convert';

import 'package:http/http.dart' as http;

import 'detection_service.dart';

class SyncSummary {
  const SyncSummary({
    required this.total,
    required this.synced,
    required this.failed,
  });

  final int total;
  final int synced;
  final int failed;
}

class SyncService {
  factory SyncService() => instance;

  SyncService._();

  static final SyncService instance = SyncService._();

  static const String _baseUrl =
      'https://o5whulvuhi.execute-api.us-east-1.amazonaws.com';

  static const String _apiKey = 'plagas-mvp-local-key';

  Future<SyncSummary> syncPendingDetections({
    required Map<String, dynamic> user,
  }) async {
    final userId = user['id']?.toString().trim() ?? '';

    final userName = user['nombre']?.toString().trim() ?? '';
    final userEmail = user['email']?.toString().trim() ?? '';
    final userPhone = user['telefono']?.toString().trim() ?? '';
    final userRole = user['rol']?.toString().trim() ?? 'AGRICULTOR';

    if (userId.isEmpty) {
      return const SyncSummary(
        total: 0,
        synced: 0,
        failed: 0,
      );
    }

    final detections = await DetectionService.instance.getPendingSyncDetections(
      userId: userId,
      limit: 20,
    );

    var synced = 0;
    var failed = 0;

    for (final detection in detections) {
      final detectionId = detection['id']?.toString() ?? '';

      if (detectionId.isEmpty) {
        failed++;
        continue;
      }

      await DetectionService.instance.markDetectionAsSyncing(
        detectionId: detectionId,
      );

      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/sync/detecciones'),
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'x-api-key': _apiKey,
          },
          body: jsonEncode({
            'local_id': detectionId,
            'usuario_id': userId,
            'usuario_nombre': userName,
            'usuario_email': userEmail,
            'usuario_telefono': userPhone,
            'usuario_rol': userRole,
            'cultivo_id': detection['cultivo_id'],
            'parcela_nombre': detection['nombre_parcela'],
            'plaga_nombre': detection['nombre_comun'],
            'plaga_cientifica': detection['nombre_cientifico'],
            'confianza': detection['confianza'],
            'fecha_hora': detection['fecha_hora'],
            'latitud': detection['latitud'],
            'longitud': detection['longitud'],
            'ubicacion_origen': detection['ubicacion_origen'],
            'box_left': detection['box_left'],
            'box_top': detection['box_top'],
            'box_right': detection['box_right'],
            'box_bottom': detection['box_bottom'],
            'ruta_imagen_local': detection['ruta_imagen'],
            'imagen_url': null,
            'dispositivo_id': detection['dispositivo_id'],
          }),
        );

        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            body['ok'] == true) {
          await DetectionService.instance.markDetectionAsSynced(
            detectionId: detectionId,
            cloudId: body['cloud_id']?.toString() ?? detectionId,
          );
          synced++;
        } else {
          final message = body['message']?.toString() ??
              'Error HTTP ${response.statusCode} al sincronizar';
          await DetectionService.instance.markDetectionSyncError(
            detectionId: detectionId,
            errorMessage: message,
          );
          failed++;
        }
      } catch (error) {
        await DetectionService.instance.markDetectionSyncError(
          detectionId: detectionId,
          errorMessage: error.toString(),
        );
        failed++;
      }
    }

    return SyncSummary(
      total: detections.length,
      synced: synced,
      failed: failed,
    );
  }
}
