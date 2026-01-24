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

# This updates the config.php file once initialization through setup.php has completed
if [[ -f /var/www/localhost/htdocs/config.php ]]; then 
    # Company Name
    sed -i "s/\$config_app_name.*';/\$config_app_name = '$ITFLOW_NAME';/g" /var/www/localhost/htdocs/config.php

    # MariaDB Host
    sed -i "s/\$dbhost.*';/\$dbhost = '$ITFLOW_DB_HOST';/g" /var/www/localhost/htdocs/config.php

    # Database Password
    sed -i "s/\$dbpassword.*';/\$dbpassword = '$ITFLOW_DB_PASS';/g" /var/www/localhost/htdocs/config.php

    # Base URL - add protocol if not present
    if [[ "$ITFLOW_URL" =~ ^https?:// ]]; then
        # URL already has protocol
        BASE_URL="$ITFLOW_URL"
    else
        # No protocol - use ITFLOW_HTTPS env var (default: true)
        if [ "${ITFLOW_HTTPS:-true}" = "true" ]; then
            BASE_URL="https://$ITFLOW_URL"
        else
            BASE_URL="http://$ITFLOW_URL"
        fi
    fi
    sed -i "s|\$config_base_url.*';|\$config_base_url = '$BASE_URL';|g" /var/www/localhost/htdocs/config.php

    # Repo Branch
    sed -i "s/\$repo_branch.*';/\$repo_branch = '$ITFLOW_REPO_BRANCH';/g" /var/www/localhost/htdocs/config.php
    
    find /var/www/localhost/htdocs -type d -exec chmod 775 {} \;
    find /var/www/localhost/htdocs -type f -exec chmod 664 {} \;
    chmod 640 /var/www/localhost/htdocs/config.php
else 
    chmod -R 777 /var/www/localhost/htdocs
fi

# Start Cron

crond &

# Execute the command in the dockerfile's CMD
exec "$@"
