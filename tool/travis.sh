#!/bin/bash

# Fast fail the script on failures.
set -xe

dartanalyzer --fatal-warnings --fatal-infos .

pub run test -p vm -j 1
pub run build_runner test -- -p vm -j 1
pub run build_runner test -- -p firefox -j 1
pub run build_runner test -- -p chrome -j 1
pub run test -p chrome -j 1

