import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''
# pub run test -p vm -j 1 test/type_adapter_test.dart
dart run build_runner test -- -p chrome -j 1 test/type_adapter_test.dart test/timestamp_test.dart test/blob_test.dart
''');
}
