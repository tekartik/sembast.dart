import 'package:process_run/shell_run.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  dart test -p chrome test/web test/multiplatform

''');
}
