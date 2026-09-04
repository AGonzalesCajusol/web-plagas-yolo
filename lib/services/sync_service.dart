import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'detection_service.dart';

class SyncSummary {
  const SyncSummary({
    required this.total,
    required this.synced,
    required this.failed,
    this.remoteTotal = 0,
    this.downloaded = 0,
  });

  final int total;
  final int synced;
  final int failed;

  final int remoteTotal;

  final int downloaded;
}

class ImageUploadData {
  const ImageUploadData({
    required this.uploadUrl,
    required this.imageKey,
  });

  final String uploadUrl;
  final String imageKey;
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
    final userEmail = user['email']?.toString().trim().toLowerCase() ?? '';
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
        final imageKey = await _uploadDetectionImageIfAvailable(detection);

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
            'nivel_afectacion': detection['nivel_afectacion'],
            'metodo_evaluacion': detection['metodo_evaluacion'],
            'rango_afectacion': detection['rango_afectacion'],
            'recomendacion_version': detection['recomendacion_version'],
            'ruta_imagen_local': detection['ruta_imagen'],
            'image_key': imageKey,
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
        final errorMessage =
            error.toString().contains('Error al subir imagen a S3')
                ? 'Error al subir imagen a S3'
                : error.toString();
        await DetectionService.instance.markDetectionSyncError(
          detectionId: detectionId,
          errorMessage: errorMessage,
        );
        failed++;
      }
    }

    var remoteTotal = 0;
    var downloaded = 0;

    if (userEmail.isNotEmpty) {
      try {
        final remoteDetections = await _downloadRemoteDetections(
          usuarioEmail: userEmail,
        );

        remoteTotal = remoteDetections.length;

        downloaded = await DetectionService.instance.insertRemoteDetections(
          userId: userId,
          remoteDetections: remoteDetections,
        );
      } catch (_) {}
    }

    await DetectionService.instance.normalizeExistingPestNames();

    return SyncSummary(
      total: detections.length,
      synced: synced,
      failed: failed,
      remoteTotal: remoteTotal,
      downloaded: downloaded,
    );
  }

  Future<List<Map<String, dynamic>>> _downloadRemoteDetections({
    required String usuarioEmail,
  }) async {
    final uri = Uri.parse('$_baseUrl/sync/detecciones').replace(
      queryParameters: {
        'usuario_email': usuarioEmail,
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'x-api-key': _apiKey,
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['ok'] == true) {
      final detections = body['detections'];

      if (detections is List) {
        return detections
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
      }

      return [];
    }

    final message = body['message']?.toString() ??
        'Error HTTP ${response.statusCode} descargando detecciones';

    throw Exception(message);
  }

  Future<String?> _uploadDetectionImageIfAvailable(
    Map<String, dynamic> detection,
  ) async {
    final imagePath = detection['ruta_imagen']?.toString().trim();
    if (imagePath == null || imagePath.isEmpty) return null;

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) return null;

    final detectionId = detection['id']?.toString().trim() ?? '';
    if (detectionId.isEmpty) return null;

    final contentType = _resolveImageContentType(imagePath);
    if (contentType == null) {
      throw Exception('Error al subir imagen a S3: formato no soportado');
    }

    final uploadData = await _requestImageUploadUrl(
      detectionId: detectionId,
      contentType: contentType,
    );

    final bytes = await imageFile.readAsBytes();

    final uploadResponse = await http.put(
      Uri.parse(uploadData.uploadUrl),
      headers: {
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (uploadResponse.statusCode == 200 || uploadResponse.statusCode == 204) {
      return uploadData.imageKey;
    }

    throw Exception(
      'Error al subir imagen a S3: HTTP ${uploadResponse.statusCode}',
    );
  }

  Future<ImageUploadData> _requestImageUploadUrl({
    required String detectionId,
    required String contentType,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sync/image-upload-url'),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'x-api-key': _apiKey,
      },
      body: jsonEncode({
        'detection_id': detectionId,
        'content_type': contentType,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['ok'] == true) {
      final uploadUrl = body['upload_url']?.toString() ?? '';
      final imageKey = body['image_key']?.toString() ?? '';

      if (uploadUrl.isNotEmpty && imageKey.isNotEmpty) {
        return ImageUploadData(
          uploadUrl: uploadUrl,
          imageKey: imageKey,
        );
      }
    }

    final message = body['message']?.toString() ??
        'Error HTTP ${response.statusCode} solicitando URL de imagen';

    throw Exception('Error al subir imagen a S3: $message');
  }

  String? _resolveImageContentType(String path) {
    final normalizedPath = path.toLowerCase();

    if (normalizedPath.endsWith('.jpg') || normalizedPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (normalizedPath.endsWith('.png')) {
      return 'image/png';
    }

    if (normalizedPath.endsWith('.webp')) {
      return 'image/webp';
    }

    return null;
  }
}
