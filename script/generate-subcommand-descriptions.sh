#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

incremental_dir=.incremental/generate-subcommand-descriptions.sh
this_file=./script/generate-subcommand-descriptions.sh
adoc_files=(docs/aerospace-*.adoc)
incremental_file="$incremental_dir/$(shasum -a 256 "$this_file" "${adoc_files[@]}" | shasum -a 256 | awk '{print $1}')"

if test -f "$incremental_file"; then
    exit 0
fi

entries() {
    for file in "${adoc_files[@]}"; do
        if grep -q 'exec-and-forget' <<< "$file"; then
            continue
        fi
        subcommand=$(basename "$file" | sed 's/^aerospace-//' | sed 's/\.adoc$//')
        desc="$(grep :manpurpose: "$file" | sed -E 's/:manpurpose: //')"
        echo "    [\"  $subcommand\", \"$desc\"],"
    done
}

cat <<EOF > ./Sources/Cli/subcommandDescriptionsGenerated.swift
// FILE IS GENERATED FROM docs/aerospace-*.adoc files
// TO REGENERATE THE FILE RUN generate.sh

let subcommandDescriptions = [
$(entries)
]
EOF

rm -rf "$incremental_dir" && mkdir -p "$incremental_dir" && touch "$incremental_file"
