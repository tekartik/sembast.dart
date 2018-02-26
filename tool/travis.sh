#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings .

pub run test -p vm -j 1
pub run test -p firefox -j 1
pub run test -p chrome -j 1

# test dartdevc support
pub build example/web --web-compiler=dartdevc
