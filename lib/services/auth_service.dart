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

    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.trim();
    final normalizedPassword = password.trim();

    if (!_isValidName(normalizedName)) return false;
    if (!_isValidEmail(normalizedEmail)) return false;
    if (!_isValidPhone(normalizedPhone)) return false;
    if (!_isValidPassword(normalizedPassword)) return false;

    final id = _generateUuidV4();

    try {
      await db.insert(
        'usuarios',
        {
          'id': id,
          'nombre': normalizedName,
          'email': normalizedEmail,
          'telefono': normalizedPhone,
          'password_hash': normalizedPassword,
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

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    if (!_isValidEmail(normalizedEmail)) return null;
    if (normalizedPassword.isEmpty) return null;

    final result = await db.query(
      'usuarios',
      columns: ['id', 'nombre', 'email', 'telefono', 'rol'],
      where: 'email = ? AND password_hash = ?',
      whereArgs: [normalizedEmail, normalizedPassword],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return result.first;
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    final db = await LocalDB.instance.database;
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) return null;

    final result = await db.query(
      'usuarios',
      columns: ['id', 'nombre', 'email', 'telefono', 'rol'],
      where: 'id = ?',
      whereArgs: [normalizedId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return result.first;
  }

  Future<bool> updateUserProfile({
    required String id,
    required String name,
    required String email,
    required String phone,
  }) async {
    final db = await LocalDB.instance.database;

    final normalizedId = id.trim();
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.trim();

    if (normalizedId.isEmpty) return false;
    if (!_isValidName(normalizedName)) return false;
    if (!_isValidEmail(normalizedEmail)) return false;
    if (!_isValidPhone(normalizedPhone)) return false;

    try {
      final rowsAffected = await db.update(
        'usuarios',
        {
          'nombre': normalizedName,
          'email': normalizedEmail,
          'telefono': normalizedPhone,
        },
        where: 'id = ?',
        whereArgs: [normalizedId],
      );

      return rowsAffected > 0;
    } on DatabaseException {
      return false;
    }
  }

  bool _isValidName(String value) {
    return value.length >= 3;
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    return regex.hasMatch(value);
  }

  bool _isValidPhone(String value) {
    final onlyNumbers = value.replaceAll(RegExp(r'\D'), '');
    return onlyNumbers.length >= 9;
  }

  bool _isValidPassword(String value) {
    return value.length >= 6;
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