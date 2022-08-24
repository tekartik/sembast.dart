import 'package:process_run/shell_run.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  dart pub run build_runner test -- -p chrome -j 1 test/web test/multiplatform

''');
}
