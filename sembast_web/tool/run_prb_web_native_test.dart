import 'package:process_run/shell_run.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  pub run build_runner test -- -p chrome test/web

''');
}
