#!/bin/bash
# Date: 01-06-2015
# http://www.khmer.pw

USERWEB=nginx

# add user without login
adduser -s /sbin/nologin ${USERWEB}

#  install our dependencies
yum -y install gcc-c++ pcre-devel zlib-devel make openssl-devel wget unzip

# check http://nginx.org/en/download.html for the latest version
NGINX_VERSION=1.8.0

# change directory to /root
cd /root/
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xzf nginx-${NGINX_VERSION}.tar.gz
cd /$HOME/nginx-${NGINX_VERSION}/
sh ./configure "--prefix=/etc/nginx" "--sbin-path=/usr/sbin/nginx" "--conf-path=/etc/nginx/nginx.conf" \
	"--error-log-path=/var/log/nginx/error.log" "--http-log-path=/var/log/nginx/access.log" \
	"--pid-path=/var/run/nginx.pid" "--lock-path=/var/run/nginx.lock" \
	"--http-client-body-temp-path=/var/cache/nginx/client_temp" \
	"--http-proxy-temp-path=/var/cache/nginx/proxy_temp" \
	"--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp" \
	"--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp" \
	"--http-scgi-temp-path=/var/cache/nginx/scgi_temp" \
	"--user=nginx" "--group=nginx" "--with-http_ssl_module" "--with-http_realip_module" \
	"--with-http_addition_module" "--with-http_sub_module" \
	"--with-http_dav_module" "--with-http_flv_module" "--with-http_mp4_module" \
	"--with-http_gunzip_module" "--with-http_gzip_static_module" \
	"--with-http_random_index_module" "--with-http_secure_link_module" \
	"--with-http_stub_status_module" "--with-http_auth_request_module" \
	"--with-mail" "--with-mail_ssl_module" "--with-file-aio" "--with-ipv6"
make
make install

# Check http://wiki.nginx.org/InitScripts for init script of nginx

cat << 'EOF' > /usr/lib/systemd/system/nginx.service
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Move existing nginx configuration if available
if [ -f /etc/nginx/nginx.conf ]; then
	# use unix time stamp
    mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.$(date +"%s")
fi

# Get it from distribution of nginx-1.8
cat << 'EOF' > /etc/nginx/nginx.conf
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}

EOF

# Create necessary directory
mkdir -p /var/cache/nginx/client_temp
mkdir -p /etc/nginx/conf.d/
mkdir -p /usr/nginx/html/

if [ -f /etc/nginx/conf.d/default.conf ]; then
	# use unix time stamp
    mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.$(date +"%s")
fi

cat << 'EOF' > /etc/nginx/conf.d/default.conf
server {
    listen       80;
    server_name  localhost;

    #charset koi8-r;
    #access_log  /var/log/nginx/log/host.access.log  main;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
EOF

systemctl enable nginx
systemctl start nginx
