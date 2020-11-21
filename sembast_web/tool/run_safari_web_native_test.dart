// @dart=2.9
import 'package:process_run/shell_run.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  pub run test -p safari test/web

''');
}
