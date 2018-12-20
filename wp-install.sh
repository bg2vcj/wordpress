#!/bin/bash

install_php7(){
    
    yum -y install epel-release
    sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo
    yum -y install  wget unzip vim tcl expect expect-devel
    echo "安装PHP7"
    rpm -ivh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
    rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
    yum -y install php70w php70w-mysql php70w-gd php70w-xml php70w-fpm
    service php-fpm start
    chkconfig php-fpm on

}

install_mysql(){

    echo "安装mysql"
    wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    rpm -ivh mysql-community-release-el7-5.noarch.rpm
    yum -y install mysql-server
    systemctl enable mysqld.service
    systemctl start  mysqld.service
    echo "配置mysql"
    mysqlpasswd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
    
/usr/bin/expect << EOF
spawn mysql_secure_installation
expect "password for root" {send "\r"}
expect "root password" {send "Y\r"}
expect "New password" {send "$mysqlpasswd\r"}
expect "Re-enter new password" {send "$mysqlpasswd\r"}
expect "Remove anonymous users" {send "Y\r"}
expect "Disallow root login remotely" {send "Y\r"}
expect "database and access" {send "Y\r"}
expect "Reload privilege tables" {send "Y\r"}
spawn mysql -u root -p
expect "Enter password" {send "$mysqlpasswd\r"}
expect "mysql" {send "create database wordpress_db;\r"}
expect "mysql" {send "exit\r"}
EOF

}

install_nginx(){

    echo "安装nginx"
    rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
    yum install -y nginx
    systemctl enable nginx.service
    rm -f /etc/nginx/conf.d/default.conf
    rm -f /etc/nginx/nginx.conf

cat > /etc/nginx/nginx.conf <<-EOF
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

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
EOF

cat > /etc/nginx/conf.d/default.conf<<-EOF
server {
    listen       80;
    server_name  localhost;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    location ~ \.php$ {
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }
}
EOF

}

config_php(){

    echo "配置php和php-fpm"
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/;" /etc/php.ini
    sed -i "s/user = apache/user = nginx/;s/group = apache/group = nginx/;s/pm.start_servers = 5/pm.start_servers = 3/;s/pm.min_spare_servers = 5/pm.min_spare_servers = 3/;s/pm.max_spare_servers = 35/pm.max_spare_servers = 8/;" /etc/php-fpm.d/www.conf
    systemctl restart php-fpm.service
    systemctl start nginx.service

}

install_wp(){

    echo "安装WordPress"
    cd /usr/share/nginx/html
    wget https://cn.wordpress.org/wordpress-5.0.1-zh_CN.zip
    unzip wordpress-5.0.1-zh_CN.zip
    mv wordpress/* ./
    cp wp-config-sample.php wp-config.php
    echo "配置参数"
    sed -i "s/database_name_here/wordpress_db/;s/username_here/root/;s/password_here/$mysqlpasswd/;" /usr/share/nginx/html/wp-config.php
    echo "define('FS_METHOD', "direct");" >> /usr/share/nginx/html/wp-config.php
    chown -R nginx /usr/share/nginx/html
    echo "=========================="
    echo "WordPress服务端配置已完成"
    echo "请打开浏览器访问服务器进行前台配置"

}

uninstall_wp(){

    echo "你的wordpress数据将全部丢失！！你确定要卸载吗？"
    read -s -n1 -p "按回车键开始卸载，按ctrl+c取消"
    yum remove -y php70w php70w-mysql php70w-gd php70w-xml php70w-fpm mysql-server nginx
    rm -rf /usr/share/nginx/html/*
    echo "卸载完成"
}

start_menu(){
    clear
    echo "======================================="
    echo " 介绍：适用于CentOS7，一键安装wordpress"
    echo " 作者：atrandys"
    echo " 网站：www.atrandys.com"
    echo " Youtube：atrandys"
    echo "======================================="
    echo "1. 一键安装wordpress"
    echo "2. 卸载wordpress"
    echo "0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
	install_php7
    	install_mysql
    	install_nginx
	config_php
    	install_wp
	;;
	2)
	uninstall_wp
	;;
	0)
	exit 1
	;;
	*)
	clear
	echo "请输入正确数字"
	sleep 5s
	start_menu
	;;
    esac
}

start_menu
