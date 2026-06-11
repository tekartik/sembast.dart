import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';

/// Database factory sandbox extension.
extension SembastDatabaseFactorySandboxExtension on DatabaseFactory {
  /// Database factory sandboxing.
  ///
  /// Every database opened, deleted or checked through the returned factory
  /// is located below [path] in the original factory.
  ///
  /// If the factory is already a sandbox, the tree is sanitized (i.e. never 2
  /// levels of sandboxing).
  ///
  /// Works with any [DatabaseFactory] implementation (io, memory, web).
  DatabaseFactory sandbox({required String path}) {
    var self = this;
    if (self is _DatabaseFactorySandbox) {
      return _DatabaseFactorySandbox(
        delegate: self.delegate,
        rootPath: self.delegatePath(path),
      );
    }
    return _DatabaseFactorySandbox(delegate: this, rootPath: path);
  }
}

class _DatabaseFactorySandbox implements DatabaseFactory {
  _DatabaseFactorySandbox({required this.delegate, required String rootPath})
    : rootPath = p.normalize(rootPath);

  /// The wrapped factory.
  final DatabaseFactory delegate;

  /// The root path of the sandbox in the delegate factory.
  final String rootPath;

  /// Converts a path in the sandboxed factory to a path in the delegate
  /// factory. Throws an [ArgumentError] if the path escapes the sandbox.
  String delegatePath(String path) {
    var relativePath = p.isAbsolute(path)
        ? p.relative(path, from: p.rootPrefix(path))
        : path;
    var fullPath = p.normalize(p.join(rootPath, relativePath));
    if (!p.isWithin(rootPath, fullPath)) {
      throw ArgumentError.value(
        path,
        'path',
        'Path is outside of the sandbox root $rootPath',
      );
    }
    return fullPath;
  }

  @override
  bool get hasStorage => delegate.hasStorage;

  @override
  Future<Database> openDatabase(
    String path, {
    int? version,
    OnVersionChangedFunction? onVersionChanged,
    DatabaseMode? mode,
    SembastCodec? codec,
  }) => delegate.openDatabase(
    delegatePath(path),
    version: version,
    onVersionChanged: onVersionChanged,
    mode: mode,
    codec: codec,
  );

  @override
  Future<void> deleteDatabase(String path) =>
      delegate.deleteDatabase(delegatePath(path));

  @override
  Future<bool> databaseExists(String path) =>
      delegate.databaseExists(delegatePath(path));

  @override
  String toString() => 'sandbox($delegate, $rootPath)';
}
