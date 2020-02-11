import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  shell = shell.pushd('sembast_test');
  await shell.run('''

pub get
pub run test test/idb_io_test.dart test/io_factory_test.dart

    ''');
  shell = shell.popd();
}
