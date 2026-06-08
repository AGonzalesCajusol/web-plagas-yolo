import '../database/local_db.dart';

class ProfileService {
  factory ProfileService() => instance;

  ProfileService._();

  static final ProfileService instance = ProfileService._();

  Future<Map<String, dynamic>> getDashboardMetrics({
    required String userId,
  }) async {
    final db = await LocalDB.instance.database;

    final totalDetectionsResult = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM detecciones
      INNER JOIN cultivos ON detecciones.cultivo_id = cultivos.id
      WHERE cultivos.usuario_id = ?
    ''', [userId]);

    final mostFrequentPestResult = await db.rawQuery('''
      SELECT plagas.nombre_comun AS nombre, COUNT(*) AS total
      FROM detecciones
      INNER JOIN plagas ON detecciones.plaga_id = plagas.id
      INNER JOIN cultivos ON detecciones.cultivo_id = cultivos.id
      WHERE cultivos.usuario_id = ?
      GROUP BY plagas.nombre_comun
      ORDER BY total DESC
      LIMIT 1
    ''', [userId]);

    final mostAffectedCropResult = await db.rawQuery('''
      SELECT cultivos.nombre_parcela AS nombre, COUNT(*) AS total
      FROM detecciones
      INNER JOIN cultivos ON detecciones.cultivo_id = cultivos.id
      WHERE cultivos.usuario_id = ?
      GROUP BY cultivos.nombre_parcela
      ORDER BY total DESC
      LIMIT 1
    ''', [userId]);

    final pendingSyncResult = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM detecciones
      INNER JOIN cultivos ON detecciones.cultivo_id = cultivos.id
      WHERE sincronizado = 0
        AND cultivos.usuario_id = ?
    ''', [userId]);

    final syncedResult = await db.rawQuery('''
  SELECT COUNT(*) AS total
  FROM detecciones
  INNER JOIN cultivos ON detecciones.cultivo_id = cultivos.id
  WHERE sincronizado = 1
    AND cultivos.usuario_id = ?
''', [userId]);

    final errorSyncResult = await db.rawQuery('''
  SELECT COUNT(*) AS total
  FROM detecciones
  INNER JOIN cultivos ON detecciones.cultivo_id = cultivos.id
  WHERE detecciones.sync_status = 'error'
    AND cultivos.usuario_id = ?
''', [userId]);

    final syncingResult = await db.rawQuery('''
  SELECT COUNT(*) AS total
  FROM detecciones
  INNER JOIN cultivos ON detecciones.cultivo_id = cultivos.id
  WHERE detecciones.sync_status = 'sincronizando'
    AND cultivos.usuario_id = ?
''', [userId]);

    return {
      'totalDetecciones': totalDetectionsResult.first['total'] ?? 0,
      'plagaMasFrecuente': mostFrequentPestResult.isNotEmpty
          ? mostFrequentPestResult.first['nombre'] ?? 'Sin datos'
          : 'Sin datos',
      'parcelaMasAfectada': mostAffectedCropResult.isNotEmpty
          ? mostAffectedCropResult.first['nombre'] ?? 'Sin datos'
          : 'Sin datos',
      'pendientesSincronizacion': pendingSyncResult.first['total'] ?? 0,
      'sincronizadas': syncedResult.first['total'] ?? 0,
      'erroresSincronizacion': errorSyncResult.first['total'] ?? 0,
      'sincronizando': syncingResult.first['total'] ?? 0,
    };
  }
}
