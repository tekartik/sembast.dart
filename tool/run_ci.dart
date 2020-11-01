import 'package:dev_test/package.dart';

Future main() async {
  for (var dir in [
    '.',
    'sembast',
    'sembast_test',
    'sembast_web',
  ]) {
    await packageRunCi(dir);
  }
}
