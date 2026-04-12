import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
    this.passwordHash,
    this.ageOfChild,
  });

  final String id;
  final String fullName;
  final String email;
  final DateTime createdAt;
  final String? passwordHash;
  final int? ageOfChild;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    DateTime createdAt;

    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      createdAt = DateTime.now().toUtc();
    }

    return AuthUser(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      createdAt: createdAt,
      passwordHash: json['passwordHash'] as String?,
      ageOfChild: json['ageOfChild'] as int?,
    );
  }

  Map<String, dynamic> toJson({bool includeSensitiveFields = false}) {
    final payload = <String, dynamic>{
      'id': id,
      'fullName': fullName,
      'email': email,
      'emailNormalized': AuthService.normalizeEmail(email),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'ageOfChild': ageOfChild,
    };

    if (includeSensitiveFields && passwordHash != null) {
      payload['passwordHash'] = passwordHash;
    }

    return payload;
  }
}

class AuthService {
  static const String _localUsersKey = 'auth_users_local';
  static const String _currentUserKey = 'auth_current_user';
  static const String _usersCollection = 'users';

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static Future<AuthUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_currentUserKey);

    if (encoded == null || encoded.isEmpty) {
      print('AUTH DEBUG: No current user found in SharedPreferences');
      return null;
    }

    final user = AuthUser.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    print('AUTH DEBUG: Current user from SharedPreferences - email: ${user.email}, ageOfChild: ${user.ageOfChild}');
    return user;
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  static Future<AuthUser> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final cleanName = fullName.trim();
    final normalizedEmail = normalizeEmail(email);

    if (cleanName.isEmpty) {
      throw ArgumentError('Please enter your full name.');
    }
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw ArgumentError('Password should be at least 6 characters long.');
    }

    final passwordHash = _hashPassword(password);

    try {
      final existing = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .where('emailNormalized', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw StateError('An account with this email already exists.');
      }

      final docRef = FirebaseFirestore.instance.collection(_usersCollection).doc();
      final user = AuthUser(
        id: docRef.id,
        fullName: cleanName,
        email: normalizedEmail,
        createdAt: DateTime.now().toUtc(),
        passwordHash: passwordHash,
      );

      await docRef.set(user.toJson(includeSensitiveFields: true));
      await _saveCurrentUser(user);
      return user;
    } on FirebaseException catch (error) {
      throw StateError('Unable to save account to Firestore: ${error.message ?? error.code}');
    }
  }

  static Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      throw ArgumentError('Please enter your password.');
    }

    final passwordHash = _hashPassword(password);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_usersCollection)
          .where('emailNormalized', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw StateError('No account found for this email.');
      }

      final userJson = snapshot.docs.first.data();
      print('AUTH DEBUG: Complete user document from Firebase: $userJson');
      final storedHash = userJson['passwordHash'] as String?;

      if (storedHash == null || storedHash != passwordHash) {
        throw StateError('Incorrect password.');
      }

      final user = AuthUser.fromJson(userJson);
      print('AUTH DEBUG: Created AuthUser - email: ${user.email}, ageOfChild: ${user.ageOfChild}');
      await _saveCurrentUser(user);
      
      // Also save ageOfChild to SharedPreferences for easy access
      if (user.ageOfChild != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('childAgeValue', user.ageOfChild!);
        await prefs.setString('childAge', '${user.ageOfChild} years');
        print('AUTH DEBUG: Saved ageOfChild ${user.ageOfChild} to SharedPreferences');
      }
      
      return user;
    } on FirebaseException catch (error) {
      throw StateError('Unable to read account from Firestore: ${error.message ?? error.code}');
    }
}

  static Future<void> _saveCurrentUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = user.toJson(includeSensitiveFields: false);
    await prefs.setString(_currentUserKey, jsonEncode(payload));
  }

}
