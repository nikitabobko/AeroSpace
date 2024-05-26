#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

complgen_version="v0.1.8"
complgen="./.bin/complgen-${complgen_version}-$(arch)"
if ! [ -f "$complgen" ]; then
    rm -rf .bin && mkdir -p .bin
    if [ "$(arch)" = arm64 ]; then
        wget -O "$complgen" "https://github.com/adaszko/complgen/releases/download/${complgen_version}/complgen-aarch64-apple-darwin"
    elif [ "$(arch)" = i386 ]; then
        wget -O "$complgen" "https://github.com/adaszko/complgen/releases/download/${complgen_version}/complgen-x86_64-apple-darwin"
    else
        echo "Unknown architecture $(arch)" > /dev/stderr
        exit 1
    fi
    chmod +x "$complgen"
fi

rm -rf .shell-completion && mkdir -p \
    .shell-completion/zsh \
    .shell-completion/fish \
    .shell-completion/bash

"$complgen" aot args-grammar.conf \
    --zsh-script .shell-completion/zsh/_aerospace 2>&1 \
    --fish-script .shell-completion/fish/aerospace.fish 2>&1 \
    --bash-script .shell-completion/bash/aerospace 2>&1

# Check basic syntax
zsh -c 'autoload -Uz compinit; compinit; source ./.shell-completion/zsh/_aerospace'
fish -c 'source ./.shell-completion/fish/aerospace.fish'
bash -c 'source ./.shell-completion/bash/aerospace'
