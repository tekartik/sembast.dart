import 'package:sembast/sembast.dart';

/// Open options.
class DatabaseOpenOptions {
  /// version.
  final int? version;

  /// open callback.
  final OnVersionChangedFunction? onVersionChanged;

  /// open mode.
  final DatabaseMode? mode;

  /// codec.
  final SembastCodec? codec;

  /// Open options.
  DatabaseOpenOptions({
    this.version,
    this.onVersionChanged,
    this.mode,
    this.codec,
  });

  @override
  String toString() {
    var map = <String, Object?>{};
    if (version != null) {
      map['version'] = version;
    }
    if (mode != null) {
      map['mode'] = mode;
    }
    if (codec != null) {
      map['codec'] = codec;
    }
    return map.toString();
  }
}
