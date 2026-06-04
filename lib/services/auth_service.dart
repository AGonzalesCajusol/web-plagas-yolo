import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';

class AuthService {
  Future<bool> registerUser(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    final db = await LocalDB.instance.database;
    final id = _generateUuidV4();

    try {
      // TODO: Implementar hashing seguro (ej. bcrypt)
      await db.insert(
        'usuarios',
        {
          'id': id,
          'nombre': name,
          'email': email,
          'telefono': phone,
          'password_hash': password,
          'rol': 'AGRICULTOR',
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return true;
    } on DatabaseException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final db = await LocalDB.instance.database;

    // TODO: Implementar hashing seguro (ej. bcrypt)
    final result = await db.query(
      'usuarios',
      columns: ['id', 'nombre', 'email', 'telefono', 'rol'],
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email, password],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return result.first;
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final chars = bytes.map(hex).join();

    return '${chars.substring(0, 8)}-'
        '${chars.substring(8, 12)}-'
        '${chars.substring(12, 16)}-'
        '${chars.substring(16, 20)}-'
        '${chars.substring(20)}';
  }
}
