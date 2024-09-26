/// Notifier.
///
/// On the web, it will use LocalStorage notification using `'sembast_web:revision/<db>': <revision>`
abstract class Notifier {
  /// Notify with the given revision
  void notifyRevision(int revision);
}
