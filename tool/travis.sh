#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings \
  lib/sembast.dart \
  lib/sembast_io.dart \
  lib/sembast_memory.dart \

pub run test -p vm
pub run test -p firefox -j 1