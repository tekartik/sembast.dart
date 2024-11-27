import 'package:process_run/shell_run.dart';

Future main() async {
  var shell = Shell();

  // Edit as needed during dev
  await shell.run('''

  dart pub run build_runner test -- -p chrome -j 1 test/multiplatform/sembast_io_api_test.dart test/multiplatform/sembast_web_api_test.dart

''');
}
