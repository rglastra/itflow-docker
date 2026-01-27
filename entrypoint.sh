#!/bin/ash

sed -i "s/^Listen.*/Listen $ITFLOW_PORT/g" /etc/apache2/httpd.conf

# if itflow is not downloaded, perform the download
if [[ ! -f /var/www/localhost/htdocs/index.php ]]; then 
    echo "Cloning ITFlow from $ITFLOW_REPO (branch: $ITFLOW_REPO_BRANCH)..."
    rm -rf /var/www/localhost/htdocs/*
    git clone --branch $ITFLOW_REPO_BRANCH https://$ITFLOW_REPO /var/www/localhost/htdocs
else
    echo "ITFlow already exists, skipping clone"
    cd /var/www/localhost/htdocs
fi

git config --global --add safe.directory /var/www/localhost/htdocs

# Verify permissions of itflow git repository
chown -R apache:apache /var/www/localhost/htdocs

# Persist config.php and uploads to volume
mkdir -p /var/itflow-data
if [[ -f /var/itflow-data/config.php ]]; then
    ln -sf /var/itflow-data/config.php /var/www/localhost/htdocs/config.php
fi
if [[ -d /var/itflow-data/uploads ]]; then
    rm -rf /var/www/localhost/htdocs/uploads
    ln -sf /var/itflow-data/uploads /var/www/localhost/htdocs/uploads
fi

# This updates the config.php file once initialization through setup.php has completed
if [[ -f /var/www/localhost/htdocs/config.php ]]; then 
    # Company Name
    sed -i "s/\$config_app_name.*';/\$config_app_name = '$ITFLOW_NAME';/g" /var/www/localhost/htdocs/config.php

    # MariaDB Host
    sed -i "s/\$dbhost.*';/\$dbhost = '$ITFLOW_DB_HOST';/g" /var/www/localhost/htdocs/config.php

    # Database Password
    sed -i "s/\$dbpassword.*';/\$dbpassword = '$ITFLOW_DB_PASS';/g" /var/www/localhost/htdocs/config.php

    # Base URL - should be domain only without protocol
    BASE_URL="${ITFLOW_URL#http://}"
    BASE_URL="${BASE_URL#https://}"
    sed -i "s|\$config_base_url.*';|\$config_base_url = '$BASE_URL';|g" /var/www/localhost/htdocs/config.php

    # Repo Branch
    sed -i "s/\$repo_branch.*';/\$repo_branch = '$ITFLOW_REPO_BRANCH';/g" /var/www/localhost/htdocs/config.php
    
    find /var/www/localhost/htdocs -type d -exec chmod 775 {} \;
    find /var/www/localhost/htdocs -type f -exec chmod 664 {} \;
    chmod 640 /var/www/localhost/htdocs/config.php
    
    # Copy config to persistent storage
    cp -f /var/www/localhost/htdocs/config.php /var/itflow-data/config.php
else 
    chmod -R 777 /var/www/localhost/htdocs
fi

# Ensure uploads directory is persisted
if [[ ! -d /var/itflow-data/uploads ]]; then
    mv /var/www/localhost/htdocs/uploads /var/itflow-data/uploads 2>/dev/null || mkdir -p /var/itflow-data/uploads
    ln -sf /var/itflow-data/uploads /var/www/localhost/htdocs/uploads
fi
chown -R apache:apache /var/itflow-data

# Start Cron
crond &

# Execute the command in the dockerfile's CMD
exec "$@"
