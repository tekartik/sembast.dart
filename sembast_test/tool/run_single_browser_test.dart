import 'package:process_run/shell_run.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  pub run test -p chrome test/multiplatform/sembast_io_api_test.dart test/multiplatform/sembast_web_api_test.dart

''');
}
