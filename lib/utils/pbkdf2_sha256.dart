import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PKCS#5 PBKDF2 с HMAC-SHA256 (RFC 2898).
Uint8List pbkdf2Sha256({
  required List<int> password,
  required List<int> salt,
  int iterations = 310000,
  int dkLen = 32,
}) {
  final prf = Hmac(sha256, password);
  final blocks = <int>[];
  var blockIndex = 0;
  while (blocks.length < dkLen) {
    blockIndex++;
    final counter = <int>[
      (blockIndex >> 24) & 0xff,
      (blockIndex >> 16) & 0xff,
      (blockIndex >> 8) & 0xff,
      blockIndex & 0xff,
    ];
    final blockBytes = Uint8List.fromList(<int>[...salt, ...counter]);
    var u = Uint8List.fromList(prf.convert(blockBytes).bytes);
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(prf.convert(u).bytes);
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    blocks.addAll(t);
  }
  return Uint8List.fromList(blocks.sublist(0, dkLen));
}

/// Упаковка соли и выхода PBKDF2 в одну строку JSON для Secure Storage.
String encodePasswordRecord({
  required int iterations,
  required Uint8List salt,
  required Uint8List hash,
}) {
  return jsonEncode({
    'v': 2,
    'algo': 'pbkdf2_sha256',
    'i': iterations,
    's': base64Encode(salt),
    'h': base64Encode(hash),
  });
}

bool verifyPasswordAgainstRecord(String password, String recordJson) {
  try {
    final m = Map<String, dynamic>.from(jsonDecode(recordJson) as Map);
    if ((m['v'] as num?)?.toInt() == 2 &&
        m['algo'] == 'pbkdf2_sha256' &&
        m['s'] is String &&
        m['h'] is String &&
        m['i'] is num) {
      final salt = base64Decode(m['s'] as String);
      final expected = base64Decode(m['h'] as String);
      final iter = (m['i'] as num).toInt();
      final derived = pbkdf2Sha256(
        password: utf8.encode(password),
        salt: salt,
        iterations: iter,
        dkLen: expected.length,
      );
      if (derived.length != expected.length) return false;
      var ok = 0;
      for (var i = 0; i < derived.length; i++) {
        ok |= derived[i] ^ expected[i];
      }
      return ok == 0;
    }
  } catch (_) {}
  return false;
}
