import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sembast/sembast.dart';

class SembastCodecImpl implements SembastCodec {
  @override
  final String signature;
  @override
  final Codec<Map<String, dynamic>, String> codec;

  SembastCodecImpl({@required this.signature, @required this.codec});
}

/// The encoded signature is a map {'signature': signature} encoded by itself!
String getCodecEncodedSignature(SembastCodec codec) {
  if (codec != null) {
    return codec?.codec?.encode({'signature': codec.signature});
  }
  return null;
}
