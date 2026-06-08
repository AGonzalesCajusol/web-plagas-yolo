import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';

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
          'dispositivo_id': Platform.localHostname,
          'sincronizado': 0,
        });
      });

      return true;
    } catch (error, stackTrace) {
      // ignore: avoid_print
      print('Error guardando deteccion: $error');
      // ignore: avoid_print
      print(stackTrace);
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

    return deletedRows > 0;
  }

  Future<int> clearUserDetections({
    required String userId,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return 0;
    }

    return db.delete(
      'detecciones',
      where: '''
        cultivo_id IN (
          SELECT id FROM cultivos WHERE usuario_id = ?
        )
      ''',
      whereArgs: [normalizedUserId],
    );
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
}
