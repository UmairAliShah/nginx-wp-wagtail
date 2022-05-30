# **Setup NGINX Web Server with PHP-FPM and WordPress**

## **Case Study**
* Create a new MySQL database and user for WordPress. The MySQL user should be restricted to the WordPress database only.
* Create a new Linux user and deploy the application within the user's home directory.
* Use [wp-cli](https://wp-cli.org/) to setup WordPress.
* Setup a [separate PHP-FPM Pool](https://gist.github.com/fyrebase/62262b1ff33a6aaf5a54) for WordPress.
* Make sure that the PHP-FPM pool processes run as the Linux user you have created.
* The PHP-FPM pool for WordPress should [override PHP settings](https://support.cloudways.com/how-to-change-php-fpm-settings/) so that files above 25MB can be uploaded to the server via the WordPress admin console.
* Make sure that NGINX version, OS version and PHP version in HTTP headers is not publicly visible when browsing the web server via curl command e.g. curl http://localhost/ or curl http://IP_ADDRESS_OF_YOUR_VM.
* Use secure practices as described in the Getting started with NGINX series in the Setup an NGINX Web Server card.
* NGINX should be configured in such a way that wp-config.php file is not accessible via the browser.
* Use your Google search skills where necessary.
* This exercise is meant to make you aware of how web apps are deployed. Hence, you are required to understand every aspect of the deployment that you do. Do not copy paste from provided URLs blindly and understand why is a specific URL provided to you.
* At the end of the task, write a detailed document of how you deployed the application and what you have learned about the different components you used.
* Push your work to DevOps-Lab git repository after reading the repository's README.md file.

# **Getting Started**
Update the server where you are setting up the wordpress site
```bash
sudo apt-get update -y
```
## **Install Nnginx, PHP, PHP-FPM**
Install Nginx and PHP-FPM with some additional php packages
```bash
sudo apt install nginx php php-fpm \
php-common php-mysql \
php-xml php-xmlrpc php-curl php-gd \
php-cli php-dev php-imap \
php-mbstring php-zip -y
```
## **Replace Nginx File to server php files**
Replace the content of `default` file in `/etc/nginx/sites-available/` with
```bash
server {
    listen         80 default_server;
    listen         [::]:80 default_server;
    server_name    _;
    root           /var/www/html;
    index          index index.php index.html index.htm index.nginx-debian.html

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
```
In the above file, the following block opens the php-fpm socket to server php files
```console
    location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
	}
```

## **Hide Nginx Version Publicly**
To hide the NGINX version publicly, set `server_tokens` to **off** in `/etc/nginx/nginx.conf`
```bash
sudo sed -i 's/# server_tokens off;/server_tokens off;/g' /etc/nginx/nginx.conf
```
## **PHP Info file**
To check if nginx is serving the php fine
```bash
sudo cat << EOF > /var/www/html/info.php
<?php phpinfo(); ?>
EOF
```
Reload nginx and restart php-fpm service
```bash
sudo nginx -s reload
sudo systemctl restart nginx.service php7.4-fpm.service
```
> On hitting the server ip you will see nginx default html page and by appending `/info.php` after ip you will get information about php


## **Create linux user for php-fpm separate pool**
```bash
sudo useradd -m deployuser
```
Disable password for **deployuser** 
```console
sudo visudo
```
Add this in the file and save it
> deployuser ALL=(ALL) NOPASSWD:ALL 

## **Configure seperate pool for wordpress site**
Make new file with the name of `wordpress_site.conf` 
```bash
sudo cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/wordpress_site.conf
```
Now edit `wordpress_site.conf` file
```bash
sudo vim /etc/php/7.4/fpm/pool.d/wordpress_site.conf
```
### Replace the following content
Replace pool name [www] with 
> [wordpress_site]

Change user and group
>   user = deployuser

>   group = deployuser

>   listen.owner = deployuser

>   listen.group = deployuser

Replace socket `listen = /run/php/php7.4-fpm.sock` with 
> listen = /run/php/php7.4-fpm-wordpress-site.sock

Add the following parameters so that large files can be uploaded via wordpress sites
>   php_admin_value[post_max_size] = 45M        
    php_admin_value[upload_max_filesize] = 45M

Save the file
<br>

### Replace the socket path in nginx file
Replace `fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;` in `/etc/nginx/sites-available/default` with 
> fastcgi_pass unix:/var/run/php/php7.4-fpm-wordpress-site.sock;

Reload the services
```bash
sudo php-fpm7.4 -t
sudo systemctl restart php7.4-fpm.service
sudo nginx -s reload 
sudo systemctl restart nginx
```

## Install WPCLI
Run the following commands to install wpcli
```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
php wp-cli.phar --info
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```

## Install MYSQL server, Configure DB, and User
```bash
sudo apt update
sudo apt install mysql-server -y 
sudo mysql -uroot
CREATE DATABASE wordpress;
CREATE USER 'wordpress_user'@'localhost' IDENTIFIED BY 'wordpress_user';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress_user'@'localhost';
FLUSH PRIVILEGES;
```

## Create folders in deployuser directory
Create folder for wordpress site and nginx logs in the home directory of `deployuser` 
> sudo mkdir -p /home/deployuser/logs /home/deployuser/public

Change the ownership of folders for `deployuser`
> sudo chown -R deployuser:deployuser /home/deployuser/

## Modify Nginx file for Wordpress site
Edit the `/etc/nginx/sites-available/default` 
Change the `root`, `index`, `access_log`, `error_log` paths for wordpress site and nginx logs
>   root           /home/deployuser/public/;

>   index          index.php;

>   access_log     /home/deployuser/logs/php_access.log;

>   error_log      /home/deployuser/logs/php_error.log;

## Download WP and configure site
Switch to deployuser
> sudo su - deployuser

Run the following commands
```bash
cd public
wp core download
wp core config --dbname=wordpress --dbuser=wordpress_user --dbpass=wordpress_user
wp core install --url=http://server_ip --title='Wordpress Site' --admin_user=admin --admin_email=syed.umair@arbisoft.com --admin_password=adminpass
```

## Hit the server ip with /wp-admin 
Add the login credentials for wordpress admin


## Add SSL certificate in nginx using certbot
Run these commands to generate ssl 
```bash 
sudo apt-add-repository -r ppa:certbot/certbot
sudo apt-get update
sudo apt-get install python3-certbot-nginx -y
sudo certbot --nginx -d umair-wp.bounceme.net
```
Replace the content of `default` file in `/etc/nginx/sites-available/default` with
```bash
server {
#    listen         80;
    server_name    umair-wp.bounceme.net;
    root           /home/deployuser/public/;
    index          index.php;

    access_log /home/deployuser/logs/php_access.log;
    error_log /home/deployuser/logs/php_error.log;

   location / {
		try_files $uri $uri/ =404;
  }
    location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/var/run/php/php7.4-fpm-wordpress-site.sock;
	}


   listen 443 ssl; # managed by Certbot
   ssl_certificate /etc/letsencrypt/live/umair-wp.bounceme.net/fullchain.pem; # managed by Certbot
   ssl_certificate_key /etc/letsencrypt/live/umair-wp.bounceme.net/privkey.pem; # managed by Certbot
  #  include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
  #  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {

    listen         80;
    server_name    umair-wp.bounceme.net;
#    return 404; # managed by Certbot
    return 301 https://$server_name$request_uri;

}
```

## Reference link
https://spinupwp.com/hosting-wordpress-setup-secure-virtual-server/
