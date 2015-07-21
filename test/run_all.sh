#/bin/bash

pushd $(dirname $(dirname $BASH_SOURCE))

pub run test -j 1 -r expanded -p vm -p content-shell
pub run test test/database_perf_test_slow.dart -j 1 -r expanded -p vm -p content-shell
pub run test test/database_perf_test_io_slow.dart -j 1 -r expanded
popd

