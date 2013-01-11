#!/bin/bash

if ph_is_installed apt-cyg ; then
    PH_PACKAGE_MANAGER='apt-cyg'
    PH_PACKAGE_MANAGER_ARG='install'
    PH_PACKAGE_MANAGER_BUILDTOOLS='apt-cyg install autoconf automake bison cmake gcc gcc-g++ libtool m4 make'

    # Fix required for cygwin when installing gcc
    PH_PACKAGE_MANAGER_POSTBUILD='for x in /etc/postinstall/{gcc.,gcc-[^tm]}* ; do . $x; done'

elif ph_is_installed apt-get ; then
    PH_PACKAGE_MANAGER='apt-get'
    PH_PACKAGE_MANAGER_ARG='install'
    PH_PACKAGE_MANAGER_UPDATE='update'
    PH_PACKAGE_MANAGER_BUILDTOOLS='apt-get install build-essential'

elif ph_is_installed brew ; then
    PH_PACKAGE_MANAGER='brew'
    PH_PACKAGE_MANAGER_ARG='install'
    PH_PACKAGE_MANAGER_UPDATE='update'

elif ph_is_installed pacman ; then
    PH_PACKAGE_MANAGER='pacman'
    PH_PACKAGE_MANAGER_ARG='-Sy'
    PH_PACKAGE_MANAGER_BUILDTOOLS='pacman -Sy base-devel'

elif ph_is_installed yum ; then
    PH_PACKAGE_MANAGER='yum'
    PH_PACKAGE_MANAGER_ARG='install'
    PH_PACKAGE_MANAGER_BUILDTOOLS='yum groupinstall "Development Tools" "Legacy Software Development"'

elif ph_is_installed zypper ; then
    PH_PACKAGE_MANAGER='zypper'
    PH_PACKAGE_MANAGER_ARG='install'
    PH_PACKAGE_MANAGER_BUILDTOOLS='zypper install rpmdevtools gcc gcc-c++ make'

else
    echo 'Package manager not found!'
    exit 1
fi


##
# Installs make, libtool, autoconf etc.
#
function ph_install_buildtools {
    $PH_PACKAGE_MANAGER_BUILDTOOLS

    if [ ! -z "${PH_PACKAGE_MANAGER_POSTBUILD}" ]; then
        echo ${PH_PACKAGE_MANAGER_POSTBUILD} | /bin/bash
    fi
}


##
# Installs all packages (passed as arguments)
# e.g. ph_install_packages mcrypt openssl pcre
#
# @arguments Space separated list of packages to install
#
function ph_install_packages {
    local i=0
    local CONF_PATH="${PH_INSTALL_DIR}/etc/package_map.conf"
    declare -a PH_PACKAGES

    for PACKAGE in "$@"; do
        # Search conf file for entry, take 3rd value on line as package name
        PACKAGE_MAP_PACKAGE_NAME=`grep "^${PACKAGE}:${PH_PACKAGE_MANAGER}" ${CONF_PATH} | cut -d: -f3`

        # Catch empty result of above search
        if [ -z "${PACKAGE_MAP_PACKAGE_NAME}" ]; then
            echo "ph_install_packages() - Package map not found for '${PACKAGE}:${PH_PACKAGE_MANAGER}' in ${CONF_PATH}!"
            exit

        # Count number of lines returned from above search, error if more than one
        elif [ `echo "${PACKAGE_MAP_PACKAGE_NAME}" | wc -l` -gt 1 ]; then
            echo "ph_install_packages() - Duplicate entry found for '${PACKAGE}:${PH_PACKAGE_MANAGER}' in ${CONF_PATH}!"
            exit
        fi

        # Skip package if so marked in conf file
        if [ "${PACKAGE_MAP_PACKAGE_NAME}" != "##SKIP##" ]; then

            # Detect packages that are already installed. This also supports
            # multiple entries such as "openssl-devel openssl"
            for j in `echo "${PACKAGE_MAP_PACKAGE_NAME}" | tr " " "\n"`; do
                if ph_is_installed $j ; then
                    echo "$j is already installed at `which $j`"
                else
                    PH_PACKAGES[$i]="$j"
                    ((i++))
                fi
            done
        fi
    done

    # Only run the package manager if more than 1 package made it through
    if [ ${#PH_PACKAGES[@]} -gt 0 ]; then
        # Homebrew doesn't like root
        if [ 'brew' == ${PH_PACKAGE_MANAGER} ]; then
            if [ -z ${PH_ORIGINAL_USER} ]; then
                read -p 'Homebrew requires your username please (not root): ' PH_ORIGINAL_USER
            fi
            sudo -u ${PH_ORIGINAL_USER} brew update
            sudo -u ${PH_ORIGINAL_USER} brew tap homebrew/dupes
            sudo -u ${PH_ORIGINAL_USER} brew install ${PH_PACKAGES[@]} || \
                { echo "[phundamental/package_manager] Failed to install packages: ${PH_PACKAGES[@]}"; exit 1; }

        else
            # Update package list if required
            [ ! -z ${PH_PACKAGE_MANAGER_UPDATE} ] && ${PH_PACKAGE_MANAGER} ${PH_PACKAGE_MANAGER_UPDATE}

            $PH_PACKAGE_MANAGER $PH_PACKAGE_MANAGER_ARG ${PH_PACKAGES[@]} || \
                { echo "[phundamental/package_manager] Failed to install packages: ${PH_PACKAGES[@]}"; exit 1; }
        fi
    fi
}
