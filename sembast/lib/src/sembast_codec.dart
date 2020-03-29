import 'package:sembast/sembast.dart';
import 'package:sembast/src/json_encodable_codec.dart';
import 'package:sembast/src/type_adapter_impl.dart';

/// Default codec has no toString converted and no signature.
/// as format is expected to be compatible
SembastCodec sembastCodecWithAdapters(Iterable<SembastTypeAdapter> adapters) {
  var sembastCodec = SembastCodec(
      codec: null,
      signature: null,
      jsonEncodableCodec: JsonEncodableCodec(adapters: adapters));
  return sembastCodec;
}

/// Json Codec with supports for DateTime and Blobs (UInt8List)
SembastCodec sembastCodecDefault =
    sembastCodecWithAdapters([sembastBlobAdapter, sembastTimestampAdapter]);
