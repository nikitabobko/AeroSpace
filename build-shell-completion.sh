#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-dep.sh --complgen

rm -rf .shell-completion && mkdir -p \
    .shell-completion/zsh \
    .shell-completion/fish \
    .shell-completion/bash

./.deps/cargo-root/bin/complgen aot ./grammar/commands-bnf-grammar.txt \
    --zsh-script .shell-completion/zsh/_aerospace \
    --fish-script .shell-completion/fish/aerospace.fish \
    --bash-script .shell-completion/bash/aerospace

if ! (not-outdated-bash --version | grep -q 'version 5'); then
    echo "bash version is too old. At least version 5 is required" > /dev/stderr
    exit 1
fi

# Check basic syntax
zsh -c 'autoload -Uz compinit; compinit; source ./.shell-completion/zsh/_aerospace'
fish -c 'source ./.shell-completion/fish/aerospace.fish'
not-outdated-bash -c 'source ./.shell-completion/bash/aerospace'
