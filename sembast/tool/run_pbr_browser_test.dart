// @dart=2.9
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''
# single test: pub run build_runner test -- -p chrome -j 1 test/encrypt_codec_test.dart
pub run build_runner test -- -p chrome -j 1
''');
}
