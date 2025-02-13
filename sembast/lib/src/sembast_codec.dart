import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/json_encodable_codec.dart';
import 'package:sembast/src/type_adapter_impl.dart';

/// Default codec has no toString converted and no signature.
/// as format is expected to be compatible
SembastCodec sembastCodecWithAdapters(Iterable<SembastTypeAdapter> adapters) {
  var sembastCodec = SembastCodec(
    codec: null,
    signature: null,
    jsonEncodableCodec: JsonEncodableCodec(adapters: adapters),
  );
  return sembastCodec;
}

/// Json Codec with supports for DateTime and Blobs (UInt8List)
SembastCodec sembastCodecDefault = sembastCodecWithAdapters([
  sembastBlobAdapter,
  sembastTimestampAdapter,
]);

/// Get content codec.
Codec<Object?, String> sembastCodecContentCodec(SembastCodec? sembastCodec) =>
    sembastCodecContentCodecOrNull(sembastCodec) ?? json;

/// Get content codec. Needed for indexeddb where we save the value as is if no
/// codec is specified.
Codec<Object?, String>? sembastCodecContentCodecOrNull(
  SembastCodec? sembastCodec,
) => sembastCodec?.codec;

/// Get json encodable codec.
JsonEncodableCodec sembastCodecJsonEncodableCodec(SembastCodec? sembastCodec) =>
    sembastCodec?.jsonEncodableCodec ?? sembastDefaultJsonEncodableCodec;

/// Encode a sembast value to json encodable format.
Object sembastCodecToJsonEncodable(SembastCodec? sembastCodec, Object value) =>
    sembastCodecJsonEncodableCodec(sembastCodec).encode(value);

/// Decode a sembast value from json encodable format.
Object sembastCodecFromJsonEncodable(
  SembastCodec? sembastCodec,
  Object value,
) => sembastCodecJsonEncodableCodec(sembastCodec).decode(value);
