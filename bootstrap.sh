#!/bin/bash

cat <<EOA
     _             _                   _       _
 ___| |_ _ _ ___ _| |___ _____ ___ ___| |_ ___| |
| . |   | | |   | . | .'|     | -_|   |  _| .'| |
|  _|_|_|___|_|_|___|__,|_|_|_|___|_|_|_| |__,|_|
EOA
echo -n '|_|'

for i in `ls -1 ${PH_INSTALL_DIR}/functions.d`; do
    echo -n '.'
    . ${PH_INSTALL_DIR}/functions.d/$i
done

echo -e "Bootstrap complete \n"

echo "Operating System: ${PH_OS} (${PH_OS_FLAVOUR})"
echo "    Architecture: ${PH_ARCH}"
echo "  Number of CPUs: ${PH_NUM_CPUS}"
echo " Package Manager: ${PH_PACKAGE_MANAGER}"
echo ""
