import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''
pub run test -p vm -j 1
pub run build_runner test -- -p vm -j 1
pub run build_runner test -- -p firefox -j 1
pub run build_runner test -- -p chrome -j 1
pub run test -p chrome -j 1
''');
}
