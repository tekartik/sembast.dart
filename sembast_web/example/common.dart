import 'package:web/web.dart';
export 'package:sembast/sembast.dart';

class OutBuffer {
  OutBuffer(int maxLineCount) {
    _maxLineCount = maxLineCount;
  }
  late int _maxLineCount;
  List<String> lines = [];

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
final _output = document.getElementById('output') as HTMLElement;
void write([Object? message]) {
  print(message);
  _output.textContent = (_outBuffer..add('$message')).toString();
}
