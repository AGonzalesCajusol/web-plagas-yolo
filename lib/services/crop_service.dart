import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';

class CropService {
  factory CropService() => instance;

  CropService._();

  static final CropService instance = CropService._();

  static const String _defaultUserId = 'user_123';

  Future<List<Map<String, dynamic>>> getCultivos() async {
    final db = await LocalDB.instance.database;
    return db.query('cultivos');
  }

  Future<String> addCultivo(String nombre, String coordenadas) async {
    final db = await LocalDB.instance.database;
    final cultivoId = DateTime.now().microsecondsSinceEpoch.toString();

    await db.transaction((txn) async {
      await txn.insert(
        'usuarios',
        {
          'id': _defaultUserId,
          'nombre': 'Agricultor Local',
          'email': 'agricultor@test.com',
          'telefono': '',
          'password_hash': '',
          'rol': 'AGRICULTOR',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await txn.insert('cultivos', {
        'id': cultivoId,
        'usuario_id': _defaultUserId,
        'nombre_parcela': nombre,
        'coordenadas_sector': coordenadas,
      });
    });

    return cultivoId;
  }
}
