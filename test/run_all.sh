#/bin/bash

pushd $(dirname $(dirname $BASH_SOURCE))

rm test/tmp -rf
pub run test -p vm -p content-shell -p chrome
pub run test test/database_perf_test_slow.dart -p vm -p content-shell -p chrome
# -j 1 -r expanded
pub run test test/database_perf_test_io_slow.dart -p vm
# -j 1 -r expanded
popd

