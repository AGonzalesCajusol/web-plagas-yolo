import '../database/local_db.dart';

enum DeleteCultivoResult {
  deleted,
  hasDetections,
  notFound,
}

class CropService {
  factory CropService() => instance;

  CropService._();

  static final CropService instance = CropService._();

  Future<List<Map<String, dynamic>>> getCultivos({
    required String userId,
  }) async {
    final db = await LocalDB.instance.database;
    return db.query(
      'cultivos',
      where: 'usuario_id = ?',
      whereArgs: [userId],
      orderBy: 'nombre_parcela COLLATE NOCASE ASC',
    );
  }

  Future<String> addCultivo({
    required String userId,
    required String nombre,
    required String coordenadas,
  }) async {
    final db = await LocalDB.instance.database;
    final cultivoId = DateTime.now().microsecondsSinceEpoch.toString();

    await db.insert('cultivos', {
      'id': cultivoId,
      'usuario_id': userId,
      'nombre_parcela': nombre,
      'coordenadas_sector': coordenadas,
    });

    return cultivoId;
  }

  Future<DeleteCultivoResult> deleteCultivo({
    required String userId,
    required String cultivoId,
  }) async {
    final db = await LocalDB.instance.database;
    final normalizedUserId = userId.trim();
    final normalizedCultivoId = cultivoId.trim();

    if (normalizedUserId.isEmpty || normalizedCultivoId.isEmpty) {
      return DeleteCultivoResult.notFound;
    }

    final cultivos = await db.query(
      'cultivos',
      columns: ['id'],
      where: 'id = ? AND usuario_id = ?',
      whereArgs: [normalizedCultivoId, normalizedUserId],
      limit: 1,
    );

    if (cultivos.isEmpty) {
      return DeleteCultivoResult.notFound;
    }

    final detecciones = await db.query(
      'detecciones',
      columns: ['id'],
      where: 'cultivo_id = ?',
      whereArgs: [normalizedCultivoId],
      limit: 1,
    );

    if (detecciones.isNotEmpty) {
      return DeleteCultivoResult.hasDetections;
    }

    final deletedRows = await db.delete(
      'cultivos',
      where: 'id = ? AND usuario_id = ?',
      whereArgs: [normalizedCultivoId, normalizedUserId],
    );

    return deletedRows > 0
        ? DeleteCultivoResult.deleted
        : DeleteCultivoResult.notFound;
  }
}
