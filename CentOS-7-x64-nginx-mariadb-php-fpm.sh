#!/bin/bash
# Date: 31-05-2015

# Install nginx
rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum -y install nginx
systemctl enable nginx.service
systemctl start nginx.service

# Install MariaDB
yum -y install mariadb mariadb-server
systemctl start mariadb.service
systemctl enable mariadb.service

# Install php-fpm and several modules
yum -y install php-fpm php-cli php-mysql php-gd php-ldap php-odbc \
	php-pear php-xml php-xmlrpc php-mbstring
	
# Move existing nginx configuration if available
if [ -f /etc/nginx/nginx.conf ]; then
	# use unix time stamp
    mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.$(date +"%s")
fi

if [ -f /etc/nginx/conf.d/default.conf ]; then
	# use unix time stamp
    mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.$(date +"%s")
fi

# Create new nginx.conf
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
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    location ~ \.php$ {
        root           /usr/share/nginx/html;
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
EOF

# Replace cgi.fix_pathinfo to 0
sed -i 's/cgi.fix_pathinfo=0/cgi.fix_pathinfo=1/g' /etc/php.ini

# Enable php-fpm startup and restart it.
systemctl enable php-fpm.service
systemctl restart php-fpm.service

