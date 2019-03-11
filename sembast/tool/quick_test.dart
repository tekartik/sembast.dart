import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''
pub run test -p vm -j 1 test/all_factory_test.dart
''');
}
