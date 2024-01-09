# Docker image for ngx_http_proxy_connect_module

This is a docker image that includes [chobits/ngx_http_proxy_connect_module](https://github.com/chobits/ngx_http_proxy_connect_module) into [nginxinc/docker-nginx](https://github.com/nginxinc/docker-nginx), to achieve a common experience with the official nginx images.

## Features
- `ngx_http_proxy_connect_module` is bundled with nginx executable (not as a dynamic module).
- [openresty/lua-nginx-module](https://github.com/openresty/lua-nginx-module) is by default included as a dynamic module to provide basic authentication support (see [this guide](https://github.com/chobits/ngx_http_proxy_connect_module/issues/42#issuecomment-502985437)).
- Same usage with [nginx office image](https://hub.docker.com/_/nginx) (1.24.0-alpine), e.g., same user permissions, conf locations. Other officially supported modules can also be easily included into the image.
- The docker image size is small and only slightly larger than the official image (48.7MB vs 41.1MB).

The dockerfile is modified from the [official Dockerfile](https://github.com/nginxinc/docker-nginx/blob/master/stable/alpine/Dockerfile).

## Build

```shell
docker build -t ngx_http_proxy_connect:1.24.0.0.0.5-alpine .
```

To include other officially supported modules, add the module version and update Line 11 and Line 55. Officially supported modules are listed [here](https://hg.nginx.org/pkg-oss/file/tip/contrib/src).

## Usage

Pull `wenbushi/ngx_http_proxy_connect_module` if a prebuilt image is preferred:

```shell
docker pull wenbushi/ngx_http_proxy_connect_module
```

Refer to [chobits/ngx_http_proxy_connect_module](https://github.com/chobits/ngx_http_proxy_connect_module) and [nginx office image](https://hub.docker.com/_/nginx) for their usages.

An example `nginx.conf` (**Do not copy it AS IS**):

```conf
load_module modules/ndk_http_module.so;
load_module modules/ngx_http_lua_module.so;

user  nginx;
worker_processes  auto;

http {
    # ... http directives are ignored ...

    server {
        # Reference: https://github.com/chobits/ngx_http_proxy_connect_module?tab=readme-ov-file#configuration-example-for-connect-request-in-https
        server_name <server_name>;
        listen 443 ssl;
        listen [::]:443 ssl;

        # ssl certificate
        ssl_certificate_key            /path/to/server.key;
        ssl_certificate                /path/to/server.crt;
        ssl_session_cache              shared:SSL:1m;

        # Reference: https://github.com/chobits/ngx_http_proxy_connect_module/issues/42#issuecomment-502985437
        auth_basic "server auth";
        auth_basic_user_file "<auth_user_file>";
        rewrite_by_lua_file "<lua_file>";

        # dns resolver used by forward proxying
        resolver 1.1.1.1 ipv6=off;

        # forward proxy for CONNECT request
        proxy_connect;
        proxy_connect_allow            443 563;
        proxy_connect_connect_timeout  10s;
        proxy_connect_data_timeout     10s;

        location / {
            return 403 "Non-CONNECT requests are forbidden";
        }
    }

    # ... Other servers are ignored ...
}

```