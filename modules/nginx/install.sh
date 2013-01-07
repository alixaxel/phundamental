#!/bin/bash
###############################################################################
#                                                                             #
#                                                                             #
###############################################################################

NGINX_VERSION_STRING=$1
[ -z "$1" ] && read -p "Specify nginx version (e.g. 1.2.6): " NGINX_VERSION_STRING

ph_install_packages\
    openssl\
    pcre\
    zlib

read -p "Overwrite existing symlinks? [y/n]: " REPLY
[ "$REPLY" == "y" ] && NGINX_OVERWRITE_SYMLINKS=true || NGINX_OVERWRITE_SYMLINKS=false

ph_mkdirs \
    /usr/local/src \
    /etc/nginx-${NGINX_VERSION_STRING} \
    /var/log/nginx-${NGINX_VERSION_STRING} \
    /etc/nginx-${NGINX_VERSION_STRING}/global \
    /etc/nginx-${NGINX_VERSION_STRING}/sites-available \
    /etc/nginx-${NGINX_VERSION_STRING}/sites-enabled \
    /var/www/localhost/public

ph_creategroup nobody
ph_createuser nobody
ph_assigngroup nobody nobody

cd /usr/local/src

if [ ! -f nginx-${NGINX_VERSION_STRING}.tar.gz ]; then
    wget http://nginx.org/download/nginx-${NGINX_VERSION_STRING}.tar.gz

    if [ ! -f nginx-${NGINX_VERSION_STRING}.tar.gz ]; then
        echo "nginx source download failed!"
        return 1
    fi
fi

tar xzf nginx-${NGINX_VERSION_STRING}.tar.gz
cd nginx-${NGINX_VERSION_STRING}

CONFIGURE_ARGS=("--prefix=/usr/local/nginx-${NGINX_VERSION_STRING}" \
    "--pid-path=/usr/local/nginx-${NGINX_VERSION_STRING}/logs/nginx.pid" \
    "--error-log-path=/var/log/nginx-${NGINX_VERSION_STRING}/error.log" \
    "--http-log-path=/var/log/nginx-${NGINX_VERSION_STRING}/access.log" \
    "--conf-path=/etc/nginx-${NGINX_VERSION_STRING}/nginx.conf" \
    "--with-pcre" \
    "--with-http_ssl_module" \
    "--with-http_realip_module");

if [[ "${PH_PACKAGE_MANAGER}" == "brew" ]]; then
    # Add homebrew include directories
    CONFIGURE_ARGS=("${CONFIGURE_ARGS[@]}" \
        "--with-cc-opt=-I/usr/local/include" \
        "--with-ld-opt=-L/usr/local/lib")
fi

./configure ${CONFIGURE_ARGS[@]} && make -j ${PH_NUM_CPUS} && make install

cp ${PH_INSTALL_DIR}/modules/nginx/nginx.conf /etc/nginx-${NGINX_VERSION_STRING}/nginx.conf
cp ${PH_INSTALL_DIR}/modules/nginx/restrictions.conf /etc/nginx-${NGINX_VERSION_STRING}/global/restrictions.conf
cp ${PH_INSTALL_DIR}/modules/nginx/localhost.conf /etc/nginx-${NGINX_VERSION_STRING}/sites-available/localhost
cp ${PH_INSTALL_DIR}/modules/nginx/000-catchall.conf /etc/nginx-${NGINX_VERSION_STRING}/sites-available/000-catchall

ph_cp_inject ${PH_INSTALL_DIR}/modules/nginx/index.html /var/www/localhost/public/index.html\
    "##NGINX_VERSION_STRING##" "${NGINX_VERSION_STRING}"

# Patch nginx config files for windows
if [ "${PH_OS}" == "windows" ]; then
    ph_search_and_replace "^user" "#user" /etc/nginx-${NGINX_VERSION_STRING}/nginx.conf
    ph_search_and_replace "worker_connections  1024" "worker_connections  64" /etc/nginx-${NGINX_VERSION_STRING}/nginx.conf
fi

if $NGINX_OVERWRITE_SYMLINKS ; then
    ph_symlink /etc/nginx-${NGINX_VERSION_STRING} /etc/nginx
    ph_symlink /usr/local/nginx-${NGINX_VERSION_STRING} /usr/local/nginx
    ph_symlink /usr/local/nginx-${NGINX_VERSION_STRING}/logs /var/log/nginx
    ph_symlink /usr/local/nginx-${NGINX_VERSION_STRING}/sbin/nginx /usr/local/bin/nginx
    ph_symlink /etc/nginx-${NGINX_VERSION_STRING}/sites-available/localhost /etc/nginx-${NGINX_VERSION_STRING}/sites-enabled/localhost
    ph_symlink /etc/nginx-${NGINX_VERSION_STRING}/sites-available/000-catchall /etc/nginx-${NGINX_VERSION_STRING}/sites-enabled/000-catchall
fi

case "${PH_OS}" in \
    "linux")
        case "${PH_OS_FLAVOUR}" in \
            "arch")
            cp ${PH_INSTALL_DIR}/modules/nginx/nginx.in /etc/rc.d/nginx-${NGINX_VERSION_STRING}
            /etc/rc.d/nginx-${NGINX_VERSION_STRING} start
            ;;

            *)
            cp ${PH_INSTALL_DIR}/modules/nginx/nginx.in /etc/init.d/nginx-${NGINX_VERSION_STRING}
            /etc/init.d/nginx-${NGINX_VERSION_STRING} start
        esac
    ;;

    *)
        echo "nginx startup script not implemented for this OS... starting manually"
        /usr/local/nginx-${NGINX_VERSION_STRING}/sbin/nginx
esac
