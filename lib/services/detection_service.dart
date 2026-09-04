import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

import '../database/local_db.dart';
import '../utils/pest_name_normalizer.dart';
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
    String? nivelAfectacion,
    String? metodoEvaluacion,
    String? rangoAfectacion,
    String? recomendacionVersion,
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
        final normalizedPlagaNombre = PestNameNormalizer.normalize(plagaNombre);
        final plagaId = await _getOrCreatePlagaId(txn, normalizedPlagaNombre);

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
          'nivel_afectacion': nivelAfectacion,
          'metodo_evaluacion': metodoEvaluacion,
          'rango_afectacion': rangoAfectacion,
          'recomendacion_version': recomendacionVersion,
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
        detecciones.box_bottom,
        detecciones.nivel_afectacion,
        detecciones.metodo_evaluacion,
        detecciones.rango_afectacion,
        detecciones.recomendacion_version
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
    final normalizedPlagaNombre = PestNameNormalizer.normalize(plagaNombre);

    final rows = await txn.query(
      'plagas',
      columns: ['id'],
      where: 'nombre_comun = ? OR nombre_cientifico = ?',
      whereArgs: [normalizedPlagaNombre, normalizedPlagaNombre],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return rows.first['id'] as int;
    }

    return txn.insert('plagas', {
      'nombre_cientifico': normalizedPlagaNombre,
      'nombre_comun': normalizedPlagaNombre,
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
      detecciones.nivel_afectacion,
      detecciones.metodo_evaluacion,
      detecciones.rango_afectacion,
      detecciones.recomendacion_version,
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

  Future<int> normalizeExistingPestNames() async {
    final db = await LocalDB.instance.database;
    var changes = 0;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'plagas',
        columns: ['id', 'nombre_comun', 'nombre_cientifico'],
        orderBy: 'id ASC',
      );

      final canonicalIds = <String, int>{};

      for (final row in rows) {
        final id = row['id'] as int;

        final rawName =
            row['nombre_comun']?.toString().trim().isNotEmpty == true
                ? row['nombre_comun'].toString()
                : row['nombre_cientifico']?.toString() ?? '';

        final canonicalName = PestNameNormalizer.normalize(rawName);

        if (!canonicalIds.containsKey(canonicalName)) {
          await txn.update(
            'plagas',
            {
              'nombre_comun': canonicalName,
              'nombre_cientifico': canonicalName,
            },
            where: 'id = ?',
            whereArgs: [id],
          );

          canonicalIds[canonicalName] = id;
          changes++;
          continue;
        }

        final canonicalId = canonicalIds[canonicalName]!;

        await txn.update(
          'detecciones',
          {
            'plaga_id': canonicalId,
          },
          where: 'plaga_id = ?',
          whereArgs: [id],
        );

        await txn.delete(
          'plagas',
          where: 'id = ?',
          whereArgs: [id],
        );

        changes++;
      }
    });

    return changes;
  }

  Future<int> insertRemoteDetections({
    required String userId,
    required List<Map<String, dynamic>> remoteDetections,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty || remoteDetections.isEmpty) {
      return 0;
    }

    var inserted = 0;

    for (final remote in remoteDetections) {
      final cloudId = _remoteString(remote, const [
        'cloud_id',
        'id',
        'local_id',
      ]);

      final remoteLocalId = _remoteString(remote, const [
        'local_id',
        'id',
        'cloud_id',
      ]);

      final detectionId = cloudId ?? remoteLocalId;

      if (detectionId == null || detectionId.trim().isEmpty) {
        continue;
      }

      final existingDetectionId = await _findExistingRemoteDetectionId(
        db,
        detectionId: detectionId,
        cloudId: cloudId,
        remoteLocalId: remoteLocalId,
      );

      if (existingDetectionId != null) {
        await _downloadAndAttachRemoteImageIfMissing(
          db,
          detectionId: existingDetectionId,
          remote: remote,
        );
        continue;
      }

      final localImagePath = await _downloadRemoteImageIfAvailable(
        remote: remote,
        detectionId: detectionId,
      );

      final insertedRowId = await db.transaction((txn) async {
        final cultivoId = await _resolveOrCreateRemoteCultivoId(
          txn,
          userId: normalizedUserId,
          remote: remote,
        );

        final rawPlagaNombre = _remoteString(remote, const [
              'plaga_nombre',
              'plaga_cientifica',
            ]) ??
            'Sin diagnóstico';

        final plagaNombre = PestNameNormalizer.normalize(rawPlagaNombre);

        final plagaId = await _getOrCreatePlagaId(txn, plagaNombre);

        return txn.insert(
          'detecciones',
          {
            'id': detectionId,
            'cultivo_id': cultivoId,
            'plaga_id': plagaId,
            'plaga_real_manual_id': null,
            'confianza': _remoteDouble(remote, const ['confianza']) ?? 0.0,
            'fecha_hora': _remoteString(remote, const ['fecha_hora']) ??
                DateTime.now().toIso8601String(),
            'latitud': _remoteDouble(remote, const ['latitud']),
            'longitud': _remoteDouble(remote, const ['longitud']),
            'ubicacion_origen':
                _remoteString(remote, const ['ubicacion_origen']) ??
                    'sincronizado',
            'box_left': _remoteDouble(remote, const ['box_left']),
            'box_top': _remoteDouble(remote, const ['box_top']),
            'box_right': _remoteDouble(remote, const ['box_right']),
            'box_bottom': _remoteDouble(remote, const ['box_bottom']),
            'nivel_afectacion':
                _remoteString(remote, const ['nivel_afectacion']),
            'metodo_evaluacion':
                _remoteString(remote, const ['metodo_evaluacion']),
            'rango_afectacion':
                _remoteString(remote, const ['rango_afectacion']),
            'recomendacion_version':
                _remoteString(remote, const ['recomendacion_version']),
            'ruta_imagen': localImagePath,
            'dispositivo_id':
                _remoteString(remote, const ['dispositivo_id']) ?? 'Nube',
            'sincronizado': 1,
            'cloud_id': cloudId ?? detectionId,
            'sync_status': 'sincronizado',
            'last_sync_at': DateTime.now().toIso8601String(),
            'sync_error': null,
            'retry_count': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      });

      if (insertedRowId > 0) {
        inserted++;
      }
    }

    return inserted;
  }

  Future<String?> _findExistingRemoteDetectionId(
    Database db, {
    required String detectionId,
    String? cloudId,
    String? remoteLocalId,
  }) async {
    final values = <String>{
      detectionId.trim(),
      if (cloudId != null && cloudId.trim().isNotEmpty) cloudId.trim(),
      if (remoteLocalId != null && remoteLocalId.trim().isNotEmpty)
        remoteLocalId.trim(),
    };

    for (final value in values) {
      final rows = await db.query(
        'detecciones',
        columns: ['id'],
        where: 'id = ? OR cloud_id = ?',
        whereArgs: [value, value],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return rows.first['id']?.toString();
      }
    }

    return null;
  }

  Future<void> _downloadAndAttachRemoteImageIfMissing(
    Database db, {
    required String detectionId,
    required Map<String, dynamic> remote,
  }) async {
    final rows = await db.query(
      'detecciones',
      columns: ['ruta_imagen'],
      where: 'id = ?',
      whereArgs: [detectionId],
      limit: 1,
    );

    if (rows.isEmpty) return;

    final currentPath = rows.first['ruta_imagen']?.toString().trim();

    if (currentPath != null && currentPath.isNotEmpty) {
      final file = File(currentPath);
      if (await file.exists()) {
        return;
      }
    }

    final downloadedPath = await _downloadRemoteImageIfAvailable(
      remote: remote,
      detectionId: detectionId,
    );

    if (downloadedPath == null || downloadedPath.trim().isEmpty) {
      return;
    }

    await db.update(
      'detecciones',
      {
        'ruta_imagen': downloadedPath,
        'last_sync_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [detectionId],
    );
  }

  Future<String?> _downloadRemoteImageIfAvailable({
    required Map<String, dynamic> remote,
    required String detectionId,
  }) async {
    final imageUrl = _remoteString(remote, const ['imagen_url']);

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(imageUrl);

    if (uri == null || !uri.hasScheme) {
      return null;
    }

    try {
      final response = await http.get(uri);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      if (response.bodyBytes.isEmpty) {
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final detectionsDirectory = Directory('${directory.path}/detecciones');

      if (!await detectionsDirectory.exists()) {
        await detectionsDirectory.create(recursive: true);
      }

      final safeDetectionId =
          detectionId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      final extension = _resolveRemoteImageExtension(
        remote: remote,
        contentType: response.headers['content-type'],
      );

      final imageFile = File(
        '${detectionsDirectory.path}/remota_$safeDetectionId.$extension',
      );

      await imageFile.writeAsBytes(response.bodyBytes, flush: true);

      return imageFile.path;
    } catch (_) {
      return null;
    }
  }

  String _resolveRemoteImageExtension({
    required Map<String, dynamic> remote,
    String? contentType,
  }) {
    final imageKey =
        _remoteString(remote, const ['image_key'])?.toLowerCase().trim() ?? '';

    if (imageKey.endsWith('.png')) return 'png';
    if (imageKey.endsWith('.webp')) return 'webp';
    if (imageKey.endsWith('.jpg') || imageKey.endsWith('.jpeg')) return 'jpg';

    final normalizedContentType = contentType?.toLowerCase().trim() ?? '';

    if (normalizedContentType.contains('png')) return 'png';
    if (normalizedContentType.contains('webp')) return 'webp';

    return 'jpg';
  }

  Future<String> _resolveOrCreateRemoteCultivoId(
    Transaction txn, {
    required String userId,
    required Map<String, dynamic> remote,
  }) async {
    final remoteCultivoId = _remoteString(remote, const ['cultivo_id']);
    final parcelaNombre = _remoteString(remote, const [
          'parcela_nombre',
          'nombre_parcela',
        ]) ??
        'Parcela sincronizada';

    if (remoteCultivoId != null && remoteCultivoId.trim().isNotEmpty) {
      final rows = await txn.query(
        'cultivos',
        columns: ['id'],
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [remoteCultivoId, userId],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return rows.first['id'] as String;
      }

      await txn.insert(
        'cultivos',
        {
          'id': remoteCultivoId,
          'usuario_id': userId,
          'nombre_parcela': parcelaNombre,
          'coordenadas_sector': '',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final insertedRows = await txn.query(
        'cultivos',
        columns: ['id'],
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [remoteCultivoId, userId],
        limit: 1,
      );

      if (insertedRows.isNotEmpty) {
        return insertedRows.first['id'] as String;
      }
    }

    final fallbackId = 'cultivo_sync_${DateTime.now().microsecondsSinceEpoch}';

    await txn.insert(
      'cultivos',
      {
        'id': fallbackId,
        'usuario_id': userId,
        'nombre_parcela': parcelaNombre,
        'coordenadas_sector': '',
      },
    );

    return fallbackId;
  }

  String? _remoteString(
    Map<String, dynamic> remote,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = remote[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return null;
  }

  double? _remoteDouble(
    Map<String, dynamic> remote,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = remote[key];

      if (value == null) continue;

      if (value is num) {
        return value.toDouble();
      }

      final parsed = double.tryParse(value.toString());

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
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
