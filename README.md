# Wordpress Docker Deploy

This repository provides a set of scripts and configurations to deploy multiple WordPress websites on a VPS using Docker. It leverages the `wordpress:fpm` image, which runs PHP-FPM for optimized performance, and uses separate Nginx, MariaDB, and Redis containers.

## Features

- Automated deployment of WordPress instances using `wordpress:fpm`.
- Separation of services for better performance and management.
- SSL configuration using Certbot.
- Volume mappings for persistent data storage.
- **Support for restoring WordPress sites from backup**: Specify paths to an SQL dump file and a `wp-content` folder to set up a site from existing backups.

## Prerequisites

- Docker and Docker Compose installed on your VPS.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/devflex-pro/pbn-vps-deploy.git
   cd pbn-vps-deploy
   ```

2. Create a new site:

   ```bash
   ./new-site.sh <DB_NAME> <DB_USER> <DB_PASS> <DOMAIN> <EMAIL> [SQL_DUMP_PATH] [WP_CONTENT_PATH]
   ```

   - If `SQL_DUMP_PATH` and `WP_CONTENT_PATH` are provided, the script will restore the site from the given SQL dump and `wp-content` backup.

## Usage

- The `new-site.sh` script automates the creation of new WordPress instances, setting up directories, configuration files, and SSL certificates.
- You can also restore a site from a backup by specifying the paths to the SQL dump file and the `wp-content` directory.

## Directory Structure

- **nginx_conf/**: Nginx configuration files for each site.
- **mariadb_data/**: Data directory for MariaDB.
- **redis_data/**: Data directory for Redis.
- **www/**: Directories for each WordPress site.

## Services

- **WordPress (`wordpress:fpm`)**: WordPress with PHP-FPM for improved performance.
- **Nginx**: Web server for handling HTTP/HTTPS traffic.
- **MariaDB**: Database server for WordPress.
- **Redis**: Caching server for speeding up database queries.

## License

This project is licensed under the MIT License.
