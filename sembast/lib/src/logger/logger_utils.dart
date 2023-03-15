/// Truncate any object for display
String logTruncateAny(Object? value) {
  return logTruncate(value?.toString() ?? '<null>');
}

/// Truncate any string for display
String logTruncate(String text, {int len = 128}) {
  if (text.length > len) {
    text = text.substring(0, len);
  }
  return text;
}
