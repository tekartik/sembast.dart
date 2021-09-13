import 'package:path/path.dart';
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  shell = shell.pushd(join('..', 'sembast'));
  await shell.run('''

dart pub get
dart test test/jdb_memory_test.dart

    ''');

  shell = shell.popd().pushd('sembast_web');
  await shell.run('''

dart pub get
dart pub run build_runner test -- -p chrome test/web

    ''');

  // pub run build_runner test -- -p chrome test/web
  shell = shell.popd().pushd('sembast_test');
  await shell.run('''

dart pub get
dart test test/idb_io_test.dart test/io_factory_test.dart

    ''');
  shell = shell.popd();
}
