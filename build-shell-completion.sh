#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

rm -rf .shell-completion && mkdir -p \
    .shell-completion/zsh \
    .shell-completion/fish \
    .shell-completion/bash

usage_file=./grammar/commands-bnf-grammar.txt

complgen --zsh ".shell-completion/zsh/_$cli_name" "$usage_file"
complgen --fish ".shell-completion/fish/$cli_name.fish" "$usage_file"
complgen --bash ".shell-completion/bash/$cli_name" "$usage_file"

# Check basic syntax
zsh -c "autoload -Uz compinit; compinit; source ./.shell-completion/zsh/_$cli_name"
fish -c "source ./.shell-completion/fish/$cli_name.fish"
if not-outdated-bash --version | grep -q 'version 5'; then
    not-outdated-bash -c "source ./.shell-completion/bash/$cli_name"
fi
