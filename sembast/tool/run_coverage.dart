// @dart=2.9
import 'package:process_run/shell.dart';
import 'package:process_run/which.dart';

Future main() async {
  var shell = Shell();

  var obsPort = 9292;
  if (whichSync('coverage') == null) {
    await shell.run('''

pub global activate coverage

''');
  }

  var testShell = Shell();
  Future start = testShell.run('''
   dart --disable-service-auth-codes --enable-vm-service=$obsPort --pause-isolates-on-exit test/io_factory_test_.dart

  ''');

  await shell.run('''
  pub global run coverage:collect_coverage --port=$obsPort --out=coverage/coverage.json --wait-paused --resume-isolates
  
  pub global run coverage:format_coverage --lcov --in=coverage/coverage.json --out=coverage/lcov.info --packages=.packages --report-on=lib

  ''');
  await start;
}
