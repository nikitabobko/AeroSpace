#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

out_file='./Sources/Common/cmdHelpGenerated.swift'

aerospace_prefix="aerospace"
____usage_prefix="   USAGE:"
_______or_prefix="      OR:"
____strip_prefix="   "

triple_quote='"""'
nl=$'\n'
sed_insert="i \\$nl"
sed_append="a \\$nl"

cat << EOF > $out_file
// FILE IS GENERATED FROM docs/aerospace-*.adoc files
// TO REGENERATE THE FILE RUN generate.sh --all

EOF

for file in docs/aerospace-*.adoc; do
    subcommand=$(basename "$file" | sed 's/^aerospace-//' | sed 's/\.adoc$//' | sed 's/-/_/g')
    sed -n -E '/tag::synopsis/, /end::synopsis/ p' "$file" | \
        sed '1d' | \
        sed '$d' | \
        sed '/^$/ d' | \
        sed "1   s/^$aerospace_prefix/$____usage_prefix/" | \
        sed "2,$ s/^$aerospace_prefix/$_______or_prefix/" | \
        sed     "s/^$____strip_prefix//" | \
        sed "1 ${sed_insert}let ${subcommand}_help_generated = $triple_quote$nl" | \
        sed "\$ ${sed_append}$triple_quote$nl" | \
        sed '2,$ s/^/    /' >> $out_file
done
