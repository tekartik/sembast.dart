import 'package:dev_test/package.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future main() async {
  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in [
      // '.',
      'sembast',
      //'sembast_test',
      //'sembast_web',
    ]) {
      await packageRunCi(dir);
    }
  }
}
