#!/bin/bash

# run Artix (OpenRC) install i3 script
if grep -q "^ID=artix" /etc/os-release \
    && command -v rc-update &>/dev/null; then
    bash ~/artix-i3/scripts/install-i3.sh
else
    echo "NOTE: Unsupported Linux distribution."
fi

# clean up user directory
if [ -f ~/.install-info ]; then
    rm -rf ~/artix-i3
fi
