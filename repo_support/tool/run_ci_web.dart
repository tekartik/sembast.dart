import 'package:dev_build/package.dart';
import 'package:path/path.dart';

Future main() async {
  for (var dir in [
    'sembast',
    'sembast_test',
    'sembast_web',
  ]) {
    await packageRunCi(join('..', dir),
        options: PackageRunCiOptions(
            testOnly: true, noVmTest: true, noNodeTest: true));
  }
}
