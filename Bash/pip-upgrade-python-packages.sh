#!/bin/bash

while read -r line; do
    test -z "${line}" && continue;
    echo "${line}";
    pkg=$(echo "$line"|cut -f 1 -d' ');
    echo -n "Upgrade now? [y/n]: ";
    read -r answer </dev/tty;
    test "${answer}" == "y" && pip install -U "${pkg}";
done< <(pip list --outdated)

##!/bin/bash
#for pkg in $( pip list --outdated | cut -d' ' -f 1 )
#do
#    echo $pkg
#    echo "update now? [yn]:"
#    read answer
#    if [ "$answer" == "y" ]; then
#        pip install -U $pkg
#    fi
#done