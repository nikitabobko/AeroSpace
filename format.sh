#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

check_uncommitted_files=0
while test $# -gt 0; do
    case $1 in
        --check-uncommitted-files) check_uncommitted_files=1; shift 1 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if test $check_uncommitted_files -eq 1; then ./script/check-uncommitted-files.sh; fi

swiftformat .

if test $check_uncommitted_files -eq 1; then ./script/check-uncommitted-files.sh; fi

swiftlint lint --quiet --fix
