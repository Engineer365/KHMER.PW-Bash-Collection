#!/bin/bash
# Date: 01-06-2015
# http://www.khmer.pw

# MySQL root password here
MYSQL_ROOT_PASS=SQLr00tP4ss

# user for khmer
USERWEB=nginx

# add user without login
adduser -s /sbin/nologin ${USERWEB}

# Configuration to set for php.ini
phpmemory_limit=16M #or what ever you want it set to
phppost_max_size=16M # post max size
phpmax_execution_time=30
phpmax_input_time=30
phpupload_max_filesize=32M
phpfix_pathinfo=0

#  install our dependencies
yum -y install gcc-c++ pcre-devel zlib-devel make openssl-devel wget unzip

# stop httpd and remove httpd
echo "--------- Removing httpd ---------"
service httpd stop
chkconfig httpd off
yum -y remove httpd -y

# check http://nginx.org/en/download.html for the latest version
NGINX_VERSION=1.6.3

# change directory to /root
cd /root/
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xzf nginx-${NGINX_VERSION}.tar.gz
cd /$HOME/nginx-${NGINX_VERSION}/

echo "--------- Compiling nginx with pagespeed ---------"

sh ./configure "--prefix=/etc/nginx/" "--sbin-path=/usr/sbin/nginx" \
	"--conf-path=/etc/nginx/nginx.conf" "--error-log-path=/var/log/nginx/error.log" \
	"--http-log-path=/var/log/nginx/access.log" "--pid-path=/var/run/nginx.pid" \
	"--lock-path=/var/run/nginx.lock" "--http-client-body-temp-path=/var/cache/nginx/client_temp" \
	"--http-proxy-temp-path=/var/cache/nginx/proxy_temp" "--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp" \
	"--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp" "--http-scgi-temp-path=/var/cache/nginx/scgi_temp" \
	"--user=nginx" "--group=nginx" "--with-http_ssl_module" "--with-http_realip_module" "--with-http_addition_module" \
	"--with-http_sub_module" "--with-http_dav_module" "--with-http_flv_module" "--with-http_mp4_module" \
	"--with-http_gzip_static_module" "--with-http_random_index_module" "--with-http_secure_link_module" \
	"--with-http_stub_status_module" "--with-mail" "--with-mail_ssl_module" "--with-file-aio" \
	"--with-ipv6"
make
make install

# Check http://wiki.nginx.org/InitScripts for init script of nginx

cat << 'EOF' > /etc/init.d/nginx
#!/bin/sh
#
# nginx - this script starts and stops the nginx daemon
#
# chkconfig:   - 85 15 
# description:  Nginx is an HTTP(S) server, HTTP(S) reverse \
#               proxy and IMAP/POP3 proxy server
# processname: nginx
# config:      /etc/nginx/nginx.conf
# config:      /etc/sysconfig/nginx
# pidfile:     /var/run/nginx.pid
 
# Source function library.
. /etc/rc.d/init.d/functions
 
# Source networking configuration.
. /etc/sysconfig/network
 
# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0
 
nginx="/usr/sbin/nginx"
prog=$(basename $nginx)
 
NGINX_CONF_FILE="/etc/nginx/nginx.conf"
 
[ -f /etc/sysconfig/nginx ] && . /etc/sysconfig/nginx
 
lockfile=/var/lock/subsys/nginx
 
make_dirs() {
   # make required directories
   user=`$nginx -V 2>&1 | grep "configure arguments:" | sed 's/[^*]*--user=\([^ ]*\).*/\1/g' -`
   if [ -z "`grep $user /etc/passwd`" ]; then
       useradd -M -s /bin/nologin $user
   fi
   options=`$nginx -V 2>&1 | grep 'configure arguments:'`
   for opt in $options; do
       if [ `echo $opt | grep '.*-temp-path'` ]; then
           value=`echo $opt | cut -d "=" -f 2`
           if [ ! -d "$value" ]; then
               # echo "creating" $value
               mkdir -p $value && chown -R $user $value
           fi
       fi
   done
}
 
start() {
    [ -x $nginx ] || exit 5
    [ -f $NGINX_CONF_FILE ] || exit 6
    make_dirs
    echo -n $"Starting $prog: "
    daemon $nginx -c $NGINX_CONF_FILE
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
    return $retval
}
 
stop() {
    echo -n $"Stopping $prog: "
    killproc $prog -QUIT
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
    return $retval
}
 
restart() {
    configtest || return $?
    stop
    sleep 1
    start
}
 
reload() {
    configtest || return $?
    echo -n $"Reloading $prog: "
    killproc $nginx -HUP
    RETVAL=$?
    echo
}
 
force_reload() {
    restart
}
 
configtest() {
  $nginx -t -c $NGINX_CONF_FILE
}
 
rh_status() {
    status $prog
}
 
rh_status_q() {
    rh_status >/dev/null 2>&1
}
 
case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart|configtest)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
            ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"
        exit 2
esac
EOF
chmod +x /etc/init.d/nginx
service nginx start
chkconfig nginx on

# open port 80
iptables -I INPUT 5 -i eth0 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
service iptables save

# install some php necessary modules
echo "--------- Install php necessary modules, mysql-server and php-fpm ---------"
yum -y install php php-mysql php-cli php-common php-pdo php-odbc php-pecl-apc php-pecl-memcache php-fpm php-soap php-gd mysql mysql-server mysql-libs mysql-server

# SETTING FOR MYSQL-SERVER
service mysqld start
chkconfig mysqld on
mysqladmin -u root password ${MYSQL_ROOT_PASS}

# setting for php-fpm
service php-fpm start
chkconfig php-fpm on

# web directory for domain
mkdir -p /etc/nginx/sites-available/

# Move existing nginx configuration if available
if [ -f /etc/nginx/nginx.conf ]; then
	# use unix time stamp
    mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.$(date +"%s")
fi

# Get it from distribution of nginx-1.6.3.tar.gz
cat << 'EOF' > /etc/nginx/nginx.conf
user  nginx;
worker_processes  1;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
        listen       0.0.0.0:80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   html;
            index  index.html index.htm;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \.php$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        location ~ \.php$ {
            root           html;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include        fastcgi_params;
        }

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #    deny  all;
        #}
    }


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}
}
EOF

# restart nginx
service nginx restart

# backup php.ini
if [ -f /etc/php.ini ]; then
	# backup and edit use unix time stamp
    cp /etc/php.ini /etc/php.ini.$(date +"%s")
fi

sed -i 's/memory_limit = .*/memory_limit = '${phpmemory_limit}'/' /etc/php.ini
sed -i 's/post_max_size = .*/post_max_size = '${phppost_max_size}'/' /etc/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = '${phpmax_execution_time}'/' /etc/php.ini
sed -i 's/max_input_time = .*/max_input_time = '${phpmax_input_time}'/' /etc/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = '${phpupload_max_filesize}'/' /etc/php.ini

sed -i 's/cgi.fix_pathinfo = .*/cgi.fix_pathinfo = '${phpfix_pathinfo}'/' /etc/php.ini
sed -i 's/;cgi.fix_pathinfo = .*/cgi.fix_pathinfo = '${phpfix_pathinfo}'/' /etc/php.ini
sed -i 's/cgi.fix_pathinfo=.*/cgi.fix_pathinfo = '${phpfix_pathinfo}'/' /etc/php.ini
sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo = '${phpfix_pathinfo}'/' /etc/php.ini

service php-fpm restart

# create phpinfo file for testing
cat << 'EOF' > /etc/nginx/html/phpinfo.php
<?php
phpinfo();
?>
 
EOF
