import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
// ignore: implementation_imports
import 'package:sembast/src/api/v2/sembast.dart';

final _random = () {
  try {
    // Try secure
    return Random.secure();
  } catch (_) {
    return Random();
  }
}();

/// Random bytes generator
Uint8List _randBytes(int length) {
  return Uint8List.fromList(
    List<int>.generate(length, (i) => _random.nextInt(256)),
  );
}

/// FOR DEMONSTRATION PURPOSES ONLY -- do not use in production as-is!
///
/// This is a demonstration on how to bring encryption to sembast, but it is an
/// insecure implementation. The encryption is unauthenticated,
/// the password conversion to bytes is underpowered (password hashes like
/// bcyrpt, scrypt, argon2id, and pbkdf2 are some examples of correct algorithms),
/// and the random bytes generator doesn't use a cryptographically secure source
/// of randomness.
///
/// See https://github.com/tekartik/sembast.dart/pull/339 for more information
///
/// Generate an encryption password based on a user input password
///
/// It uses MD5 which generates a 16 bytes blob, size needed for Salsa20
Uint8List _generateEncryptPassword(String password) {
  var blob = Uint8List.fromList(md5.convert(utf8.encode(password)).bytes);
  assert(blob.length == 16);
  return blob;
}

/// Salsa20 based encoder
class _EncryptEncoder extends Converter<Object?, String> {
  final Salsa20 salsa20;

  _EncryptEncoder(this.salsa20);

  @override
  String convert(dynamic input) {
    // Generate random initial value
    final iv = _randBytes(8);
    final ivEncoded = base64.encode(iv);
    assert(ivEncoded.length == 12);

    // Encode the input value
    final encoded = Encrypter(
      salsa20,
    ).encrypt(json.encode(input), iv: IV(iv)).base64;

    // Prepend the initial value
    return '$ivEncoded$encoded';
  }
}

/// Salsa20 based decoder
class _EncryptDecoder extends Converter<String, Object?> {
  final Salsa20 salsa20;

  _EncryptDecoder(this.salsa20);

  @override
  dynamic convert(String input) {
    // Read the initial value that was prepended
    assert(input.length >= 12);
    final iv = base64.decode(input.substring(0, 12));

    // Extract the real input
    input = input.substring(12);

    // Decode the input
    var decoded = json.decode(Encrypter(salsa20).decrypt64(input, iv: IV(iv)));
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
    return decoded;
  }
}

/// Salsa20 based Codec
class _EncryptCodec extends Codec<Object?, String> {
  late _EncryptEncoder _encoder;
  late _EncryptDecoder _decoder;

  _EncryptCodec(Uint8List passwordBytes) {
    var salsa20 = Salsa20(Key(passwordBytes));
    _encoder = _EncryptEncoder(salsa20);
    _decoder = _EncryptDecoder(salsa20);
  }

  @override
  Converter<String, Object?> get decoder => _decoder;

  @override
  Converter<Object?, String> get encoder => _encoder;
}

/// Our plain text signature
const _encryptCodecSignature = 'encrypt';

/// Create a codec to use to open a database with encrypted stored data.
///
/// Hash (md5) of the password is used (but never stored) as a key to encrypt
/// the data using the Salsa20 algorithm with a random (8 bytes) initial value
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
SembastCodec getEncryptSembastCodec({required String password}) => SembastCodec(
  signature: _encryptCodecSignature,
  codec: _EncryptCodec(_generateEncryptPassword(password)),
);

/// Wrap a factory to always use the codec
class EncryptedDatabaseFactory implements DatabaseFactory {
  final DatabaseFactory databaseFactory;
  late final SembastCodec codec;

  EncryptedDatabaseFactory({
    required this.databaseFactory,
    required String password,
  }) {
    codec = getEncryptSembastCodec(password: password);
  }

  @override
  Future<void> deleteDatabase(String path) =>
      databaseFactory.deleteDatabase(path);

  @override
  bool get hasStorage => databaseFactory.hasStorage;

  /// To use with codec, null
  @override
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnVersionChangedFunction? onVersionChanged,
    DatabaseMode? mode,
    SembastCodec? codec,
  }) {
    assert(codec == null);
    return databaseFactory.openDatabase(
      path,
      version: version,
      onVersionChanged: onVersionChanged,
      mode: mode,
      codec: this.codec,
    );
  }

  @override
  Future<bool> databaseExists(String path) {
    return databaseFactory.databaseExists(path);
  }
}
