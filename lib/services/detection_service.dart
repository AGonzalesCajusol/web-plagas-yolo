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

  static const String _defaultUserId = 'user_123';
  static const String _defaultCultivoId = 'cultivo_parcela_principal';
  static const String _defaultParcelaNombre = 'Parcela Principal';

  Future<bool> saveDetection({
    required String plagaNombre,
    required double confianza,
    required double latitud,
    required double longitud,
    required Uint8List imageBytes,
    Rect? boundingBox,
  }) async {
    try {
      final rutaImagen = await _saveImageLocally(imageBytes);
      final db = await LocalDB.instance.database;
      final now = DateTime.now();
      final fechaHora = now.toIso8601String();

      await db.transaction((txn) async {
        final plagaId = await _getOrCreatePlagaId(txn, plagaNombre);
        await _ensureDefaultUser(txn);
        final cultivoId = await _getOrCreateDefaultCultivoId(txn);

        await txn.insert('detecciones', {
          'id': 'deteccion_${now.microsecondsSinceEpoch}',
          'cultivo_id': cultivoId,
          'plaga_id': plagaId,
          'plaga_real_manual_id': null,
          'confianza': confianza,
          'fecha_hora': fechaHora,
          'latitud': latitud,
          'longitud': longitud,
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
      print('Error guardando detección: $error');
      // ignore: avoid_print
      print(stackTrace);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHistorialDetecciones() async {
    final db = await LocalDB.instance.database;

    return db.rawQuery('''
      SELECT
        detecciones.ruta_imagen,
        plagas.nombre_comun,
        plagas.nombre_cientifico,
        detecciones.confianza,
        detecciones.fecha_hora,
        detecciones.latitud,
        detecciones.longitud,
        detecciones.box_left,
        detecciones.box_top,
        detecciones.box_right,
        detecciones.box_bottom
      FROM detecciones
      INNER JOIN plagas ON detecciones.plaga_id = plagas.id
      ORDER BY detecciones.fecha_hora DESC
    ''');
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
      'descripcion': 'Registro creado automáticamente desde una detección.',
    });
  }

  Future<void> _ensureDefaultUser(Transaction txn) async {
    final rows = await txn.query(
      'usuarios',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [_defaultUserId],
      limit: 1,
    );

    if (rows.isNotEmpty) return;

    await txn.insert('usuarios', {
      'id': _defaultUserId,
      'nombre': 'Usuario de prueba',
      'email': 'user_123@local.test',
      'telefono': '',
      'password_hash': '',
      'rol': 'agricultor',
    });
  }

  Future<String> _getOrCreateDefaultCultivoId(Transaction txn) async {
    final rows = await txn.query(
      'cultivos',
      columns: ['id'],
      where: 'usuario_id = ? AND nombre_parcela = ?',
      whereArgs: [_defaultUserId, _defaultParcelaNombre],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return rows.first['id'] as String;
    }

    await txn.insert('cultivos', {
      'id': _defaultCultivoId,
      'usuario_id': _defaultUserId,
      'nombre_parcela': _defaultParcelaNombre,
      'coordenadas_sector': '0.0,0.0',
    });

    return _defaultCultivoId;
  }
}
