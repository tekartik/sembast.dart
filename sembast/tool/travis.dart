// @dart=2.9
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';
import 'run_coverage.dart' as coverage;
import 'submit_coverage_info.dart' as submit_coverage;

Future main() async {
  var shell = Shell();

  await shell.run('''

dartanalyzer --fatal-warnings --fatal-infos .
dartfmt -n --set-exit-if-changed .

pub run test -p vm -j 1
pub run build_runner test -- -p vm -j 1
pub run build_runner test -- -p chrome -j 1
pub run test -p chrome,firefox -j 1
''');

  // Skip coverage
  if (dartVersion <= Version(2, 12, 0, pre: '0')) {
    await coverage.main();
    await submit_coverage.main();
  }
}
