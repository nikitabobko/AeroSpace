#!/bin/bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

sw_vers -productVersion
# Xcode version affects the target macOS SDK that we compile against + different Xcodes bundle different Swift verions
if sw_vers -productVersion | grep -q "^14"; then # macOS 14
  sudo xcode-select -s "$XCODE_16_DEVELOPER_DIR"
else
  sudo xcode-select -s "$XCODE_26_DEVELOPER_DIR"
fi
