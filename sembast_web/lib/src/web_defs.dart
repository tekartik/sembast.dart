/// The storage revision.
class StorageRevision {
  /// Name of the database.
  final String name;

  /// Revision.
  final int revision;

  /// Revision for one storage
  StorageRevision(this.name, this.revision);

  @override
  String toString() => '$name: $revision';
}

/// For storage notification debugging/logging.
final debugStorageNotification = false; // devWarning(true);
