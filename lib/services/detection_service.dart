import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';
import 'dart:developer' as developer;

import 'package:device_info_plus/device_info_plus.dart';

class DetectionService {
  factory DetectionService() => instance;

  DetectionService._();

  static final DetectionService instance = DetectionService._();

  Future<bool> saveDetection({
    required String userId,
    required String plagaNombre,
    required double confianza,
    required double? latitud,
    required double? longitud,
    required String ubicacionOrigen,
    required Uint8List imageBytes,
    Rect? boundingBox,
    String? cultivoId,
  }) async {
    try {
      final db = await LocalDB.instance.database;
      final now = DateTime.now();
      final fechaHora = now.toIso8601String();
      final resolvedUserId = userId.trim();
      if (resolvedUserId.isEmpty) return false;

      final resolvedCultivoId = await _resolveCultivoId(
        db,
        userId: resolvedUserId,
        cultivoId: cultivoId,
      );
      if (resolvedCultivoId == null) return false;

      final rutaImagen = await _saveImageLocally(imageBytes);

      await db.transaction((txn) async {
        final plagaId = await _getOrCreatePlagaId(txn, plagaNombre);

        await txn.insert('detecciones', {
          'id': 'deteccion_${now.microsecondsSinceEpoch}',
          'cultivo_id': resolvedCultivoId,
          'plaga_id': plagaId,
          'plaga_real_manual_id': null,
          'confianza': confianza,
          'fecha_hora': fechaHora,
          'latitud': latitud,
          'longitud': longitud,
          'ubicacion_origen': ubicacionOrigen,
          'box_left': boundingBox?.left,
          'box_top': boundingBox?.top,
          'box_right': boundingBox?.right,
          'box_bottom': boundingBox?.bottom,
          'ruta_imagen': rutaImagen,
          'dispositivo_id': await _getDeviceName(),
          'sincronizado': 0,
          'cloud_id': null,
          'sync_status': 'pendiente',
          'last_sync_at': null,
          'sync_error': null,
          'retry_count': 0,
        });
      });

      return true;
    } catch (error, stackTrace) {
      // ignore: avoid_print
      developer.log(
        'Error guardando deteccion: $error',
        name: 'DetectionService',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHistorialDetecciones({
    required String userId,
  }) async {
    final db = await LocalDB.instance.database;

    return db.rawQuery('''
      SELECT
        detecciones.id,
        detecciones.ruta_imagen,
        cultivos.nombre_parcela,
        plagas.nombre_comun,
        plagas.nombre_cientifico,
        detecciones.confianza,
        detecciones.fecha_hora,
        detecciones.latitud,
        detecciones.longitud,
        detecciones.ubicacion_origen,
        detecciones.box_left,
        detecciones.box_top,
        detecciones.box_right,
        detecciones.box_bottom
      FROM detecciones
      INNER JOIN plagas ON detecciones.plaga_id = plagas.id
      LEFT JOIN cultivos ON detecciones.cultivo_id = cultivos.id
      WHERE cultivos.usuario_id = ?
      ORDER BY detecciones.fecha_hora DESC
    ''', [userId]);
  }

  Future<bool> deleteDetection({
    required String userId,
    required String detectionId,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedUserId = userId.trim();
    final normalizedDetectionId = detectionId.trim();

    if (normalizedUserId.isEmpty || normalizedDetectionId.isEmpty) {
      return false;
    }

    final rows = await db.rawQuery('''
    SELECT ruta_imagen
    FROM detecciones
    WHERE id = ?
      AND cultivo_id IN (
        SELECT id FROM cultivos WHERE usuario_id = ?
      )
    LIMIT 1
  ''', [normalizedDetectionId, normalizedUserId]);

    if (rows.isEmpty) return false;

    final imagePath = rows.first['ruta_imagen']?.toString();

    final deletedRows = await db.delete(
      'detecciones',
      where: '''
      id = ?
      AND cultivo_id IN (
        SELECT id FROM cultivos WHERE usuario_id = ?
      )
    ''',
      whereArgs: [normalizedDetectionId, normalizedUserId],
    );

    if (deletedRows > 0) {
      await _deleteImageIfExists(imagePath);
      return true;
    }

    return false;
  }

  Future<int> clearUserDetections({
    required String userId,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return 0;
    }

    final rows = await db.rawQuery('''
    SELECT ruta_imagen
    FROM detecciones
    WHERE cultivo_id IN (
      SELECT id FROM cultivos WHERE usuario_id = ?
    )
  ''', [normalizedUserId]);

    final imagePaths = rows
        .map((row) => row['ruta_imagen']?.toString())
        .where((path) => path != null && path.trim().isNotEmpty)
        .cast<String>()
        .toList();

    final deletedCount = await db.delete(
      'detecciones',
      where: '''
      cultivo_id IN (
        SELECT id FROM cultivos WHERE usuario_id = ?
      )
    ''',
      whereArgs: [normalizedUserId],
    );

    if (deletedCount > 0) {
      for (final imagePath in imagePaths) {
        await _deleteImageIfExists(imagePath);
      }
    }

    return deletedCount;
  }

  Future<String> _saveImageLocally(Uint8List imageBytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final detectionsDirectory = Directory('${directory.path}/detecciones');

    if (!await detectionsDirectory.exists()) {
      await detectionsDirectory.create(recursive: true);
    }

    final fileName = 'deteccion_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final imageFile = File('${detectionsDirectory.path}/$fileName');
    await imageFile.writeAsBytes(imageBytes, flush: true);

    return imageFile.path;
  }

  Future<int> _getOrCreatePlagaId(Transaction txn, String plagaNombre) async {
    final rows = await txn.query(
      'plagas',
      columns: ['id'],
      where: 'nombre_comun = ? OR nombre_cientifico = ?',
      whereArgs: [plagaNombre, plagaNombre],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return rows.first['id'] as int;
    }

    return txn.insert('plagas', {
      'nombre_cientifico': plagaNombre,
      'nombre_comun': plagaNombre,
      'descripcion': 'Registro creado automaticamente desde una deteccion.',
    });
  }

  Future<String?> _resolveCultivoId(
    Database db, {
    required String userId,
    String? cultivoId,
  }) async {
    final normalizedCultivoId = cultivoId?.trim();
    if (normalizedCultivoId == null || normalizedCultivoId.isEmpty) {
      return null;
    }

    final rows = await db.query(
      'cultivos',
      columns: ['id'],
      where: 'id = ? AND usuario_id = ?',
      whereArgs: [normalizedCultivoId, userId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return rows.first['id'] as String;
    }

    return null;
  }

  Future<void> _deleteImageIfExists(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return;

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      // No detenemos la eliminación del registro si falla el borrado del archivo.
      developer.log(
        'No se pudo eliminar la imagen local.',
        name: 'DetectionService',
        error: error,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncDetections({
    required String userId,
    int limit = 20,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return [];
    }

    return db.rawQuery('''
    SELECT
      detecciones.id,
      detecciones.cultivo_id,
      detecciones.plaga_id,
      detecciones.confianza,
      detecciones.fecha_hora,
      detecciones.latitud,
      detecciones.longitud,
      detecciones.ubicacion_origen,
      detecciones.box_left,
      detecciones.box_top,
      detecciones.box_right,
      detecciones.box_bottom,
      detecciones.ruta_imagen,
      detecciones.dispositivo_id,
      detecciones.sincronizado,
      detecciones.cloud_id,
      detecciones.sync_status,
      detecciones.last_sync_at,
      detecciones.sync_error,
      detecciones.retry_count,
      cultivos.nombre_parcela,
      cultivos.coordenadas_sector,
      plagas.nombre_comun,
      plagas.nombre_cientifico
    FROM detecciones
    INNER JOIN cultivos ON detecciones.cultivo_id = cultivos.id
    INNER JOIN plagas ON detecciones.plaga_id = plagas.id
    WHERE cultivos.usuario_id = ?
      AND detecciones.sincronizado = 0
      AND detecciones.sync_status IN ('pendiente', 'error')
    ORDER BY detecciones.fecha_hora ASC
    LIMIT ?
  ''', [normalizedUserId, limit]);
  }

  Future<bool> markDetectionAsSyncing({
    required String detectionId,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedDetectionId = detectionId.trim();

    if (normalizedDetectionId.isEmpty) {
      return false;
    }

    final rowsAffected = await db.update(
      'detecciones',
      {
        'sync_status': 'sincronizando',
        'sync_error': null,
      },
      where: 'id = ?',
      whereArgs: [normalizedDetectionId],
    );

    return rowsAffected > 0;
  }

  Future<bool> markDetectionAsSynced({
    required String detectionId,
    required String cloudId,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedDetectionId = detectionId.trim();
    final normalizedCloudId = cloudId.trim();

    if (normalizedDetectionId.isEmpty || normalizedCloudId.isEmpty) {
      return false;
    }

    final rowsAffected = await db.update(
      'detecciones',
      {
        'sincronizado': 1,
        'cloud_id': normalizedCloudId,
        'sync_status': 'sincronizado',
        'last_sync_at': DateTime.now().toIso8601String(),
        'sync_error': null,
      },
      where: 'id = ?',
      whereArgs: [normalizedDetectionId],
    );

    return rowsAffected > 0;
  }

  Future<bool> markDetectionSyncError({
    required String detectionId,
    required String errorMessage,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedDetectionId = detectionId.trim();

    if (normalizedDetectionId.isEmpty) {
      return false;
    }

    final rowsAffected = await db.rawUpdate('''
    UPDATE detecciones
    SET
      sync_status = ?,
      sync_error = ?,
      retry_count = COALESCE(retry_count, 0) + 1
    WHERE id = ?
  ''', [
      'error',
      errorMessage,
      normalizedDetectionId,
    ]);

    return rowsAffected > 0;
  }

  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer;
        final model = androidInfo.model;

        return '$manufacturer $model';
      }

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.utsname.machine;
      }

      return Platform.operatingSystem;
    } catch (_) {
      return 'Dispositivo móvil';
    }
  }
}
