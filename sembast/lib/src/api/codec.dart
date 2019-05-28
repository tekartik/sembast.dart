import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sembast/src/sembast_codec_impl.dart';

/// The sembast codec to use to read/write records.
///
/// It uses a user defined [codec] that must convert between a map and a
/// single line string.
///
/// It must have a public [signature], typically a comprehensive ascii name.
abstract class SembastCodec {
  /// The public signature, can be a constant, a password hash...
  String get signature;

  /// The actual codec used
  Codec<Map<String, dynamic>, String> get codec;

  /// [codec] must convert between a map and a single line string
  factory SembastCodec(
          {@required String signature,
          @required Codec<Map<String, dynamic>, String> codec}) =>
      SembastCodecImpl(signature: signature, codec: codec);
}
