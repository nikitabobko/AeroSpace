#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-deps.sh --complgen

rm -rf .shell-completion && mkdir -p \
    .shell-completion/zsh \
    .shell-completion/fish \
    .shell-completion/bash

./.deps/cargo-root/bin/complgen aot ./grammar/commands-bnf-grammar.txt \
    --zsh-script .shell-completion/zsh/_aerospace 2>&1 \
    --fish-script .shell-completion/fish/aerospace.fish 2>&1 \
    --bash-script .shell-completion/bash/aerospace 2>&1

# Check basic syntax
zsh -c 'autoload -Uz compinit; compinit; source ./.shell-completion/zsh/_aerospace'
fish -c 'source ./.shell-completion/fish/aerospace.fish'
bash -c 'source ./.shell-completion/bash/aerospace'
