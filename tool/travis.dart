import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future main() async {
  var shell = Shell();

  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in [
      'sembast',
      //'sembast_web', // not yet nnbd migrated
      //'sembast_test' // not yet nnbd migrated
    ]) {
      shell = shell.pushd(dir);
      await shell.run('''

pub get
dart tool/travis.dart

    ''');
      shell = shell.popd();
    }
  }
}
