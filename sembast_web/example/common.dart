import 'dart:html';
export 'package:sembast/sembast.dart';

class OutBuffer {
  int _maxLineCount;
  List<String> lines = [];

  OutBuffer(int maxLineCount) {
    _maxLineCount = maxLineCount ?? 100;
  }

  void add(String text) {
    lines.add(text);
    while (lines.length > _maxLineCount) {
      lines.removeAt(0);
    }
  }

  @override
  String toString() => lines.join('\n');
}

OutBuffer _outBuffer = OutBuffer(100);
Element _output = document.getElementById('output');
void write([Object message]) {
  print(message);
  _output.text = (_outBuffer..add('$message')).toString();
}
