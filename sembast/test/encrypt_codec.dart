import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:meta/meta.dart';
import 'package:sembast/sembast.dart';

class _EncryptEncoder extends Converter<Map<String, dynamic>, String> {
  final Salsa20 salsa20;

  _EncryptEncoder(this.salsa20);

  @override
  String convert(Map<String, dynamic> input) {
    String encoded = Encrypter(salsa20)
        .encrypt(json.encode(input), iv: IV.fromLength(8))
        .base64;
    return encoded;
  }
}

class _EncryptDecoder extends Converter<String, Map<String, dynamic>> {
  final Salsa20 salsa20;

  _EncryptDecoder(this.salsa20);

  @override
  Map<String, dynamic> convert(String input) {
    var decoded =
        json.decode(Encrypter(salsa20).decrypt64(input, iv: IV.fromLength(8)));
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }
}

class _EncryptCodec extends Codec<Map<String, dynamic>, String> {
  _EncryptEncoder _encoder;
  _EncryptDecoder _decoder;

  _EncryptCodec(List<int> passwordBytes) {
    var salsa20 = Salsa20(Key(Uint8List.fromList(passwordBytes)));
    _encoder = _EncryptEncoder(salsa20);
    _decoder = _EncryptDecoder(salsa20);
  }

  @override
  Converter<String, Map<String, dynamic>> get decoder => _decoder;

  @override
  Converter<Map<String, dynamic>, String> get encoder => _encoder;
}

const _encryptCodecSignature = 'encrypt';

/// Create a codec to use to open a database with encrypted stored data.
///
/// Hash (SHA256) of the password is used (but never stored) as a key to encrypt
/// the data using the Salsa20 algorithm.
///
/// This is just used as a demonstration and should not be considered as a
/// reference since its implementation (and storage format) might change.
///
/// No performance metrics has been made to check whether this is a viable
/// solution for big databases.
///
/// The usage is then
///
/// ```dart
/// // Initialize the encryption codec with a user password
/// var codec = getEncryptSembastCodec(password: '[your_user_password]');
/// // Open the database with the codec
/// Database db = await factory.openDatabase(dbPath, codec: codec);
///
/// // ...your database is ready to use
/// ```
SembastCodec getEncryptSembastCodec({@required String password}) =>
    SembastCodec(
        signature: _encryptCodecSignature,
        codec: _EncryptCodec(sha256.convert(utf8.encode(password)).bytes));
