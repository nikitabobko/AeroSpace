#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

rm -rf .shell-completion && mkdir -p \
    .shell-completion/zsh \
    .shell-completion/fish \
    .shell-completion/bash

usage_file=./grammar/commands-bnf-grammar.txt

complgen --zsh .shell-completion/zsh/_aerospace "$usage_file"
complgen --fish .shell-completion/fish/aerospace.fish "$usage_file"
complgen --bash .shell-completion/bash/aerospace "$usage_file"

# Check basic syntax
zsh -c 'autoload -Uz compinit; compinit; source ./.shell-completion/zsh/_aerospace'
fish -c 'source ./.shell-completion/fish/aerospace.fish'
if not-outdated-bash --version | grep -q 'version 5'; then
    not-outdated-bash -c 'source ./.shell-completion/bash/aerospace'
else
    echo "warning: bash completion syntax validation skipped because bash >= 5 is not available" > /dev/stderr
fi
