import 'dart:async';
import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/async_content_codec.dart';
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
  SembastCodecImpl({
    required this.signature,
    required this.codec,
    required JsonEncodableCodec? jsonEncodableCodec,
  }) : jsonEncodableCodec =
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

/// Support async codec, could throw
FutureOr<String?> getCodecEncodedSignature(SembastCodec? codec) {
  if (codec?.signature != null) {
    return codec!.encodeContent(getRawSignatureMap(codec)!);
  }
  return null;
}

/// Support async codec.
FutureOr<String?> getCodecEncodedSignatureOrNull(SembastCodec? codec) =>
    getCodecEncodedSignature(codec);

/// Get sync codec signature, never fails.
FutureOr<Map?> getCodecDecodedSignature(
  SembastCodec? codec,
  String? encodedSignature,
) {
  if (codec != null && encodedSignature != null) {
    return codec.decodeContent(encodedSignature);
  }
  return null;
}

void _checkSignaturesMatch(
  Map? rawSignatureMap,
  String? encodedSignature,
  Map? decodedSignature,
) {
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

/// Throw an error if not matching
///
/// We decode the signature to make sure it matches the raw decoded one
Future<void> checkCodecEncodedSignature(
  SembastCodec? codec,
  String? encodedSignature,
) async {
  if (codec?.signature == null && encodedSignature == null) {
    // Ignore if both signature are null
    return;
  }
  var rawSignatureMap = getRawSignatureMap(codec);
  Map? decodedSignature;
  // We catch any throwing during signature parsing as o
  try {
    decodedSignature = await getCodecDecodedSignature(codec, encodedSignature);
  } catch (_) {}
  _checkSignaturesMatch(rawSignatureMap, encodedSignature, decodedSignature);
}
