import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/json_encodable_codec.dart';

/// Sembast codec implementation.
class SembastCodecImpl implements SembastCodec {
  @override
  final String? signature;
  @override
  final Codec<Object?, String>? codec;

  @override
  JsonEncodableCodec jsonEncodableCodec;

  /// Sembast codec implementation.
  SembastCodecImpl(
      {required this.signature,
      required this.codec,
      required JsonEncodableCodec? jsonEncodableCodec})
      : jsonEncodableCodec =
            jsonEncodableCodec ?? sembastDefaultJsonEncodableCodec;

  @override
  String toString() => 'SembastCodec($signature)';
}

/// Extra the raw signaure as a map.
Map<String, Object?>? getRawSignatureMap(SembastCodec? codec) {
  if (codec != null) {
    return <String, Object?>{'signature': codec.signature};
  }
  return null;
}

/// The encoded signature is a map {'signature': signature} encoded by itself!
String? getCodecEncodedSignature(SembastCodec? codec) {
  if (codec?.signature != null) {
    return codec!.codec?.encode(getRawSignatureMap(codec)!);
  }
  return null;
}

/// Get codec signature
Map<String, Object?>? getCodecDecodedSignature(
    SembastCodec? codec, String? encodedSignature) {
  if (codec != null && encodedSignature != null) {
    try {
      var result = codec.codec?.decode(encodedSignature);
      if (result is Map) {
        return result.cast<String, Object?>();
      }
    } catch (_) {}
  }
  return null;
}

/// Throw an error if not matching
///
/// We decode the signature to make sure it matches the raw decoded one
void checkCodecEncodedSignature(SembastCodec? codec, String? encodedSignature) {
  if (codec?.signature == null && encodedSignature == null) {
    // Ignore if both signature are null
    return null;
  }
  var rawSignatureMap = getRawSignatureMap(codec);
  var decodedSignature = getCodecDecodedSignature(codec, encodedSignature);
  var matches = true;
  if (rawSignatureMap == null) {
    if (encodedSignature != null) {
      matches = false;
    }
  } else if (decodedSignature == null) {
    matches = false;
  } else {
    if ((rawSignatureMap.length != decodedSignature.length) ||
        (decodedSignature.isEmpty)) {
      matches = false;
    } else {
      // We know there is only one key/value
      if (decodedSignature.keys.first != rawSignatureMap.keys.first) {
        matches = false;
      } else if (decodedSignature.values.first !=
          rawSignatureMap.values.first) {
        matches = false;
      }
    }
  }

  if (!matches) {
    throw DatabaseException.invalidCodec('Invalid codec signature');
  }
}
