FROM nginx:1.24.0-alpine-slim

ENV NJS_VERSION   0.8.0
ENV NDK_VERSION   0.3.2
ENV MODULE_LUA_VERSION  0.10.22

COPY ./Makefile.patch /tmp

RUN set -x \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-r${PKG_RELEASE} \
        nginx-module-ndk=${NGINX_VERSION}.${NDK_VERSION}-r${PKG_RELEASE} \
        nginx-module-lua=${NGINX_VERSION}.${MODULE_LUA_VERSION}-r${PKG_RELEASE} \
    " \
# install prerequisites for public key and pkg-oss checks
    && apk add --no-cache --virtual .checksum-deps \
        openssl \
# remove the current installed nginx
    && apk del --no-network nginx \
# let's build binaries from the published packaging sources
    && tempDir=/tmp \
    && chown -R nobody:nobody ${tempDir} \
    && apk add --no-cache --virtual .build-deps \
        gcc \
        git \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        pcre2-dev \
        zlib-dev \
        linux-headers \
        libxslt-dev \
        gd-dev \
        geoip-dev \
        libedit-dev \
        bash \
        alpine-sdk \
        findutils \
    && su nobody -s /bin/sh -c " \
        export HOME=${tempDir} \
        && cd ${tempDir} \
        && curl -f -O https://hg.nginx.org/pkg-oss/archive/e5d85b3424bb.tar.gz \
        && tar xzf e5d85b3424bb.tar.gz \
        && cd ${tempDir}/pkg-oss-e5d85b3424bb/contrib/tarballs \
        && curl -L https://github.com/chobits/ngx_http_proxy_connect_module/archive/v0.0.5.tar.gz -o ngx_http_proxy_connect_module-0.0.5.tar.gz \
        && cd ${tempDir}/pkg-oss-e5d85b3424bb \
        && patch -p1 < /tmp/Makefile.patch \
        && cd alpine \
        && make base module-geoip module-image-filter module-njs module-xslt module-ndk module-lua \
        && apk index -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
        && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
        " \
    && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
    && apk del --no-network .build-deps \
    && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
# remove checksum deps
    && apk del --no-network .checksum-deps \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -f "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi \
    && if [ -f "/etc/apk/keys/nginx_signing.rsa.pub" ]; then rm -f /etc/apk/keys/nginx_signing.rsa.pub; fi \
# Bring in curl and ca-certificates to make registering on DNS SD easier
    && apk add --no-cache curl ca-certificates