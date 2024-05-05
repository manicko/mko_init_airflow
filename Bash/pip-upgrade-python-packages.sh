#!/bin/bash

while read -r line; do
    test -z "${line}" && continue;
    echo "${line}";
    pkg=$(echo "$line"|cut -f 1 -d' ');
    echo -n "Upgrade now? [y/n]: ";
    read -r answer </dev/tty;
    test "${answer}" == "y" && pip install -U "${pkg}";
done< <(pip list --outdated)