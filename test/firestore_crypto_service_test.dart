import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_dfd/services/firestore_crypto_service.dart';

void main() {
  test('encryptPayload roundtrip', () async {
    final crypto = FirestoreCryptoService.instance;
    crypto.lock();
    crypto.debugSetDek(_randomDek());

    const payload = '[{"date":"2026-01-01","title":"test"}]';
    final enc = await crypto.encryptPayload(payload);
    expect(enc['v'], FirestoreCryptoService.encVersion);
    expect(enc['alg'], FirestoreCryptoService.encAlg);
    expect(crypto.isEncryptedEnvelope(enc), isTrue);

    final clear = await crypto.decryptPayload(enc);
    expect(clear, payload);
  });

  test('isEncryptedEnvelope rejects legacy list shape', () {
    final crypto = FirestoreCryptoService.instance;
    expect(crypto.isEncryptedEnvelope([{'a': 1}]), isFalse);
    expect(
      crypto.isEncryptedEnvelope({'v': 2, 'alg': 'aes256gcm'}),
      isTrue,
    );
  });
}

Uint8List _randomDek() {
  final rnd = Random.secure();
  return Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
}
