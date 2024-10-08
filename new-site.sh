#!/bin/bash

# Входные параметры для скрипта
DB_NAME=$1
DB_USER=$2
DB_PASS=$3
DOMAIN=$4
EMAIL=$5
DUMP_FILE=$6
LOCAL_PATH=$7 

# Проверка наличия всех параметров
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Usage: $0 <DB_NAME> <DB_USER> <DB_PASS> <DOMAIN> <EMAIL> [DUMP_FILE] [LOCAL_PATH]"
    exit 1
fi

# Путь к существующему файлу docker-compose.yml
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Создание базы данных и пользователя
echo "Creating database and user..."
docker exec -i mariadb mariadb -uroot -prootpassword <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
echo "Database $DB_NAME and user $DB_USER created."

# Импорт дампа базы данных, если указан
if [ -n "$DUMP_FILE" ]; then
    if [ -f "$DUMP_FILE" ]; then
        echo "Importing database dump from $DUMP_FILE..."
        docker exec -i mariadb mariadb -u$DB_USER -p$DB_PASS $DB_NAME < "$DUMP_FILE"
        echo "Database dump imported successfully."
    else
        echo "Error: Dump file $DUMP_FILE not found."
        exit 1
    fi
fi

# Создание структуры директорий для WordPress
echo "Creating directories for WordPress..."
mkdir -p ./www/$DOMAIN/wp-content

# Копирование только директории wp-content из локальной папки
# если указано в параметрах
if [ -n "$LOCAL_PATH" ]; then
  echo "Copying wp-content from $LOCAL_PATH/$DOMAIN/wp-content to ./www/$DOMAIN/wp-content..."
  cp -r $LOCAL_PATH/$DOMAIN/wp-content/* ./www/$DOMAIN/wp-content/

# Проверка результата копирования
  if [ $? -eq 0 ]; then
    echo "wp-content successfully copied to /var/www/$DOMAIN/wp-content."
  else
    echo "Error occurred while copying wp-content."
    exit 1
  fi
fi


# Добавление нового WordPress сервиса в существующий Docker Compose файл
if grep -q "wordpress_$DOMAIN" "$DOCKER_COMPOSE_FILE"; then
    echo "WordPress service for $DOMAIN already exists in the Docker Compose file."
else
    echo "Adding WordPress service for $DOMAIN to the Docker Compose file..."
    cat <<EOL >> "$DOCKER_COMPOSE_FILE"

  wordpress_$DOMAIN:
    image: wordpress:fpm
    container_name: wordpress_$DOMAIN
    environment:
      WORDPRESS_DB_HOST: mariadb:3306
      WORDPRESS_DB_NAME: $DB_NAME
      WORDPRESS_DB_USER: $DB_USER
      WORDPRESS_DB_PASSWORD: $DB_PASS
      WORDPRESS_REDIS_HOST: redis
    volumes:
      - ./www/$DOMAIN/wp-content:/var/www/html/wp-content
    networks:
      - wp-network
    restart: always
EOL
fi


# Создание конфигурации Nginx для домена
echo "Creating Nginx configuration for $DOMAIN..."
cat <<EOL > ./nginx_conf/conf.d/$DOMAIN.conf
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://$DOMAIN\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/html;
    index index.php index.html index.htm;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass wordpress_$DOMAIN:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires max;
        log_not_found off;
    }
}
EOL

# Остановка контейнера Nginx, чтобы освободить порты 80 и 443 
docker stop nginx

# Получение SSL-сертификата через Certbot в контейнере
echo "Requesting SSL certificate..."
docker run -it --rm --name certbot \
  -p 80:80 \
  -p 443:443 \
  -v "./nginx_conf/letsencrypt:/etc/letsencrypt" \
  certbot/certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

# Перезапуск Nginx для применения сертификатов
echo "Restarting Nginx container to apply SSL certificatesand up new Wordpress container for $DOMAIN"
docker compose up -d

echo "Setup complete for $DOMAIN!"
