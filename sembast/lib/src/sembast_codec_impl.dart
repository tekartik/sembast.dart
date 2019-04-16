import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sembast/sembast.dart';

class SembastCodecImpl implements SembastCodec {
  @override
  final String signature;
  @override
  final Codec<Map<String, dynamic>, String> codec;

  SembastCodecImpl({@required this.signature, @required this.codec});

  @override
  String toString() => 'SembastCodex($signature)';
}

Map<String, dynamic> getRawSignatureMap(SembastCodec codec) {
  if (codec != null) {
    return <String, dynamic>{'signature': codec.signature};
  }
  return null;
}

/// The encoded signature is a map {'signature': signature} encoded by itself!
String getCodecEncodedSignature(SembastCodec codec) {
  if (codec != null) {
    return codec.codec?.encode(getRawSignatureMap(codec));
  }
  return null;
}

Map<String, dynamic> getCodecDecodedSignature(
    SembastCodec codec, String encodedSignature) {
  if (codec != null && encodedSignature != null) {
    try {
      return codec.codec?.decode(encodedSignature);
    } catch (_) {}
  }
  return null;
}

/// Throw an error if not matching
///
/// We decode the signature to make sure it matches the raw decoded one
void checkCodecEncodedSignature(SembastCodec codec, String encodedSignature) {
  var rawSignatureMap = getRawSignatureMap(codec);
  var decodedSignature = getCodecDecodedSignature(codec, encodedSignature);
  bool matches = true;
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
