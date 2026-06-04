import '../database/local_db.dart';

class ProfileService {
  factory ProfileService() => instance;

  ProfileService._();

  static final ProfileService instance = ProfileService._();

  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final db = await LocalDB.instance.database;

    final totalDetectionsResult = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM detecciones
    ''');

    final mostFrequentPestResult = await db.rawQuery('''
      SELECT plagas.nombre_comun AS nombre, COUNT(*) AS total
      FROM detecciones
      INNER JOIN plagas ON detecciones.plaga_id = plagas.id
      GROUP BY plagas.nombre_comun
      ORDER BY total DESC
      LIMIT 1
    ''');

    final mostAffectedCropResult = await db.rawQuery('''
      SELECT cultivos.nombre_parcela AS nombre, COUNT(*) AS total
      FROM detecciones
      LEFT JOIN cultivos ON detecciones.cultivo_id = cultivos.id
      GROUP BY cultivos.nombre_parcela
      ORDER BY total DESC
      LIMIT 1
    ''');

    final pendingSyncResult = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM detecciones
      WHERE sincronizado = 0
    ''');

    final syncedResult = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM detecciones
      WHERE sincronizado = 1
    ''');

    return {
      'totalDetecciones': totalDetectionsResult.first['total'] ?? 0,
      'plagaMasFrecuente':
          mostFrequentPestResult.isNotEmpty
              ? mostFrequentPestResult.first['nombre'] ?? 'Sin datos'
              : 'Sin datos',
      'parcelaMasAfectada':
          mostAffectedCropResult.isNotEmpty
              ? mostAffectedCropResult.first['nombre'] ?? 'Sin datos'
              : 'Sin datos',
      'pendientesSincronizacion': pendingSyncResult.first['total'] ?? 0,
      'sincronizadas': syncedResult.first['total'] ?? 0,
    };
  }
}