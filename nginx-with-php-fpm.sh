#!/bin/bash

sudo apt-get purge nginx nginx-common -y

sudo apt-get update -y 

sudo apt install nginx php-fpm -y 

sudo cat << EOF > /etc/nginx/sites-available/default
server {
    listen         80 default_server;
    listen         [::]:80 default_server;
    server_name    _;
    root           /var/www/html;
    index          index index.html index.htm index.nginx-debian.html

    access_log /var/log/nginx/php_access.log;
    error_log /var/log/nginx/php_error.log;

    location / {
		try_files $uri $uri/ =404;
    }
    location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
	}

}
EOF

sudo sed -i 's/# server_tokens off;/server_tokens off;/g' /etc/nginx/nginx.conf


sudo cat << EOF > /var/www/html/info.php
<?php phpinfo(); ?>
EOF

sudo nginx -s reload
sudo systemctl restart nginx.service php7.4-fpm.service
