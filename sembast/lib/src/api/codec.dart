import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sembast/src/sembast_codec_impl.dart';

/// The codec to use to read/write records
abstract class SembastCodec {
  /// The public signature, can be a constant, a password hash...
  String get signature;

  Codec<Map<String, dynamic>, String> get codec;

  factory SembastCodec(
          {@required String signature,
          @required Codec<Map<String, dynamic>, String> codec}) =>
      SembastCodecImpl(signature: signature, codec: codec);
}
