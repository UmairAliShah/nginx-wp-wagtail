# **Setup NGINX Web Server with Wagtail CMS using uWSGI**


# **Getting Started**

## **Create User for deployment**
Create a Linux user for application deployment
> sudo adduser --disabled-password --gecos "" deployuser

Disable password for `deployuser`
> sudo visudo  
deployuser ALL=(ALL) NOPASSWD:ALL 

Switch to user's directory
> sudo su - deployuser

## **Install MYSQL server, Configure DB, and User**
```bash
sudo apt-get update -y 
sudo apt install mysql-server -y 
sudo mysql -uroot
CREATE DATABASE wagtail;
CREATE USER 'wagtail_db_user'@'localhost' IDENTIFIED BY 'wagtail_db_user';
GRANT ALL PRIVILEGES ON wagtail.* TO 'wagtail_db_user'@'localhost';
FLUSH PRIVILEGES;
```

## **Setup Wagtail CMS**
### **Install dependencies along with virtual environment**
```bash
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install python3-pip python3-dev \ 
libmysqlclient-dev default-libmysqlclient-dev virtualenv
```

### **Setup virtual environment for python**
```bash
mkdir /home/deployuser/python-environments && cd /home/deployuser/python-environments
virtualenv --python=python3 wagtail_env
ls wagtail_env/lib
```

### **Activate Virtual Env and Setup Wagtail site**
> source wagtail_env/bin/activate

Install wagtail and mysqlclient in env
> pip install wagtail  
pip install mysqlclient

Make wagtail project
> cd /home/deployuser  
wagtail start wagtail_site

Replace default `sqlite` db with `mysql` in project
> nano /home/deployuser/wagtail_site/wagtail_site/settings/base.py


replace
```bash
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
    }
}
```
with
```bash
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'wagtail',
        'USER': 'wagtail_db_user', 
        'PASSWORD': 'wagtail_db_user',
        'HOST': 'localhost',
        'PORT': '',
    }
}
```
```bash
cd /home/deployuser/wagtail_site
pip install -r requirements.txt
```
Add server ip in `ALLOWED_HOTS`
```bash
nano /home/deployuser/wagtail_site/wagtail_site/settings/dev.py
```
> ALLOWED_HOSTS = ['server_ip']


Run `migrations` and add `super user`
```bash
cd /home/deployuser/wagtail_site
./manage.py migrate
echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@example.com', 'admin')" | python manage.py shell
```

Run server
```bash
./manage.py runserver 0.0.0.0:8000
```
Hit the server ip using `8000` port

> deactivate





## **Install uWSGI**
```bash
sudo pip install uwsgi
```
Test if website is server by using `uWSGI`
> uwsgi --http :8000 --home /home/deployuser/python-environments/wagtail_env --chdir /home/deployuser/wagtail_site -w wagtail_site.wsgi



## **Configuration file for uWSGI**
```bash
sudo mkdir -p /etc/uwsgi/sites
sudo nano /etc/uwsgi/sites/wagtail_site.ini
```
Add this in `wagtail_site.ini`
```bash
[uwsgi]
project = wagtail_site
uid = deployuser
gid = deployuser
base = /home/%(uid)

chdir = %(base)/%(project)
home = %(base)/python-environments/wagtail_env 
module = %(project).wsgi:application

disable-logging = false
listen = 100

master = true
processes = 5

socket =  /run/uwsgi/%(project).sock
chown-socket = %(uid):%(gid)
chmod-socket = 666
vacuum = true
```


## **Create a systemd Unit File for uWSGI**
```bash
sudo nano /etc/systemd/system/uwsgi.service
```

Add this in `uwsgi.service`
```bash
[Unit]
Description=uWSGI Emperor service

[Service]
ExecStartPre=/bin/bash -c 'mkdir -p /run/uwsgi; chown deployuser:deployuser /run/uwsgi'
ExecStart=/usr/local/bin/uwsgi --emperor /etc/uwsgi/sites
Restart=always
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all

[Install]
WantedBy=multi-user.target
```


## **Install and Configure Nginx as a Reverse Proxy**
```bash
sudo apt-get install nginx -y
sudo nano /etc/nginx/sites-available/default
```

Add this in `default` file
```bash
server {
	listen 80 default_server;
	listen [::]:80 default_server;

	server_name _;

    location /static/ {
        root /home/deployuser/wagtail_site;
    }
	location / {
        include         uwsgi_params;
        uwsgi_pass      unix:/run/uwsgi/wagtail_site.sock;
	}
}
```

To serve static pages through `nginx`
```bash
source python-environments/wagtail_env/bin/activate
cd wagtail_site
./manage.py collectstatic
```


Run the commands
```bash
sudo nginx -t 
sudo systemctl enable uwsgi
sudo systemctl daemon-reload
sudo systemctl restart uwsgi
sudo systemctl restart nginx
```

Hit the server IP on browser


## **Get Hostname from noip.com**

create **hostname** in noip.com 
and add server ip  against hostname 

Add `hostname` in wagtail settings file
```bash
nano /home/deployuser/wagtail_site/wagtail_site/settings/dev.py
```
> ALLOWED_HOSTS = ['hostname']

Replace `nginx` file 
```bash
sudo nano /etc/nginx/sites-available/default
```
```bash
server {
    listen 80;
    server_name umair-wagtail.bounceme.net;

    location /static/ {
        root /home/deployuser/wagtail_site;
    }

    location / {
        include         uwsgi_params;
        uwsgi_pass      unix:/run/uwsgi/wagtail_site.sock;
    }

}
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart uwsgi
sudo systemctl restart nginx
```
Hit the *domain* on `browswer`


## **Add HTTPS on site**
Get `SSL` certificates through certbot
```bash
sudo apt-add-repository -r ppa:certbot/certbot
sudo apt-get update
sudo apt-get install python3-certbot-nginx -y
sudo certbot --nginx -d umair-wagtail.bounceme.net
```

Replace `nginx` file 
```bash
sudo nano /etc/nginx/sites-available/default
```
```bash
server {
    server_name umair-wagtail.bounceme.net;
    location /static/ {
        root /home/deployuser/wagtail_site;
    }
    location / {
        include         uwsgi_params;
        uwsgi_pass      unix:/run/uwsgi/wagtail_site.sock;
    }
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/umair-wagtail.bounceme.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/umair-wagtail.bounceme.net/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

}
server {
    if ($host = umair-wagtail.bounceme.net) {
        return 301 https://$host$request_uri;
    }
    listen 80;
    server_name umair-wagtail.bounceme.net;
    return 404;

}
```
```bash
sudo systemctl restart nginx
```

Now hit the domain *https* is implemented

## **References**
https://www.digitalocean.com/community/tutorials/how-to-serve-django-applications-with-uwsgi-and-nginx-on-ubuntu-16-04
https://www.digitalocean.com/community/tutorials/how-to-set-up-let-s-encrypt-with-nginx-server-blocks-on-ubuntu-16-04