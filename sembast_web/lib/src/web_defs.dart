// ignore: unused_import
import 'sembast_import.dart';

/// The storage revision.
class NotificationRevision {
  /// Name of the database.
  final String name;

  /// Revision.
  final int revision;

  /// Revision for one storage
  NotificationRevision(this.name, this.revision);

  @override
  String toString() => '$name: $revision';
}

/// For storage notification debugging/logging.
final debugNotificationRevision = false; // devWarning(true); // false
