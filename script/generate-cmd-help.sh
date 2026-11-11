#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

incremental_dir=.incremental/generate-cmd-help.sh
this_file=./script/generate-cmd-help.sh
adoc_files=(docs/aerospace-*.adoc)
incremental_file="$incremental_dir/$(shasum -a 256 "$this_file" "${adoc_files[@]}" | shasum -a 256 | awk '{print $1}')"

if test -f "$incremental_file"; then
    exit 0
fi

out_file='./Sources/Common/cmdHelpGenerated.swift'

aerospace_prefix="aerospace"
____usage_prefix="   USAGE:"
_______or_prefix="      OR:"
____strip_prefix="   "

triple_quote='"""'

cat << EOF > $out_file
// FILE IS GENERATED FROM docs/aerospace-*.adoc files
// TO REGENERATE THE FILE RUN generate.sh

EOF

for file in "${adoc_files[@]}"; do
    subcommand=$(basename "$file" | sed 's/^aerospace-//' | sed 's/\.adoc$//' | sed 's/-/_/g')
    sed -n -E '/tag::synopsis/, /end::synopsis/ p' "$file" | \
        sed '1d' | \
        sed '$d' | \
        sed '/^$/ d' | \
        sed "1   s/^$aerospace_prefix/$____usage_prefix/" | \
        sed "2,$ s/^$aerospace_prefix/$_______or_prefix/" | \
        sed     "s/^$____strip_prefix//" | \
        sed "1 s/^/let ${subcommand}_help_generated = $triple_quote\n/" | \
        sed "\$ s/$/\n${triple_quote}/" | \
        sed '2,$ s/^/    /' >> $out_file
done

rm -rf "$incremental_dir" && mkdir -p "$incremental_dir" && touch "$incremental_file"
