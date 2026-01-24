# DO NOT USE THIS. IT WON'T WORK YET

FROM alpine:3.21

LABEL dockerfile.version="v25.05" dockerfile.release-date="2025-06-05"

# Set timezone from TZ ENV
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# PREREQS: php php-intl php-mysqli php-imap php-curl libapache2-mod-php mariadb-server git -y
# Upgrade, then install prereqs.
RUN apk update && apk upgrade

# Basic Requirements
RUN apk add \
    git\
    apache2\
    php84\
    whois\
    bind-tools\
    curl\
    tzdata

# Alpine quality of life installs
RUN apk add \
    vim\
    nano

# Install & enable php extensions
RUN apk add \ 
    php84-intl\
    php84-mysqli\
    php84-curl\
    php84-imap\
    php84-pecl-mailparse\
    php84-gd\
    php84-mbstring\
    php84-ctype\
    php84-session\
    php84-posix\
    php84-xml\
    php84-dom\
    php84-zip

# Install PHP into Apache
RUN apk add \
    php84-apache2

# Configure Apache to serve PHP files
RUN sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' /etc/apache2/httpd.conf && \
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/httpd.conf && \
    echo 'LoadModule php_module modules/mod_php84.so' >> /etc/apache2/httpd.conf && \
    echo 'AddType application/x-httpd-php .php' >> /etc/apache2/httpd.conf && \
    echo 'DirectoryIndex index.php index.html' >> /etc/apache2/httpd.conf && \
    echo '' >> /etc/apache2/httpd.conf && \
    echo '# Trust reverse proxy headers for HTTPS detection' >> /etc/apache2/httpd.conf && \
    echo 'SetEnvIf X-Forwarded-Proto "https" HTTPS=on' >> /etc/apache2/httpd.conf && \
    echo 'SetEnvIf X-Forwarded-Proto "https" HTTP_X_FORWARDED_PROTO=https' >> /etc/apache2/httpd.conf

# Set the work dir to the git repo. 
WORKDIR /var/www/localhost/htdocs

# Edit php.ini file

RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 500M/g' /etc/php84/php.ini && \
    sed -i 's/post_max_size = 8M/post_max_size = 500M/g' /etc/php84/php.ini && \
    sed -i 's/max_execution_time = 30/max_execution_time = 300/g' /etc/php84/php.ini

# Entrypoint
# On every run of the docker file, perform an entrypoint that verifies the container is good to go.
COPY entrypoint.sh /usr/bin/

# Create crontab entries

RUN echo "0       1       *       *       *       /usr/bin/php84 /var/www/localhost/htdocs/cron/cron.php" >> /etc/crontabs/apache
RUN echo "*       *       *       *       *       /usr/bin/php84 /var/www/localhost/htdocs/cron/ticket_email_parser.php" >> /etc/crontabs/apache
RUN echo "*       *       *       *       *       /usr/bin/php84 /var/www/localhost/htdocs/cron/mail_queue.php" >> /etc/crontabs/apache
RUN echo "0       2       *       *       *       /usr/bin/php84 /var/www/localhost/htdocs/cron/certificate_refresher.php" >> /etc/crontabs/apache
RUN echo "0       3       *       *       *       /usr/bin/php84 /var/www/localhost/htdocs/cron/domain_refresher.php" >> /etc/crontabs/apache

RUN chmod +x /usr/bin/entrypoint.sh

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/apache2/access.log && ln -sf /dev/stderr /var/log/apache2/error.log

# Create Symlink to PHP from PHP84
RUN ln -s /usr/bin/php84 /usr/bin/php

ENTRYPOINT [ "entrypoint.sh" ]

# Expose the apache port
EXPOSE $ITFLOW_PORT

# Start the httpd service and have logs appear in stdout
CMD [ "httpd", "-D", "FOREGROUND" ]
