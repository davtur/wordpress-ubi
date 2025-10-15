#!/bin/bash
set -e

# [DEBUG] Script start
echo "[DEBUG] Starting entrypoint script at $(date)"

# [DEBUG] Verify Apache binary exists
if ! command -v /usr/sbin/httpd >/dev/null 2>&1; then
	echo >&2 "[DEBUG] ERROR: /usr/sbin/httpd not found"
	exit 1
fi

# [DEBUG] Verify WP-CLI exists
if ! command -v /usr/local/bin/wp >/dev/null 2>&1; then
	echo >&2 "[DEBUG] ERROR: WP-CLI (/usr/local/bin/wp) not found"
	exit 1
fi

# Default env vars (matching Bitnami style)
echo "[DEBUG] Setting environment variables..."
WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST:-mariadb}
WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME:-bitnami_wordpress}
WORDPRESS_DB_USER=${WORDPRESS_DB_USER:-bn_wordpress}
WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD:-}
WORDPRESS_TABLE_PREFIX=${WORDPRESS_TABLE_PREFIX:-wp_}
WORDPRESS_BLOG_NAME=${WORDPRESS_BLOG_NAME:-WordPress}
WORDPRESS_USERNAME=${WORDPRESS_USERNAME:-user}
WORDPRESS_PASSWORD=${WORDPRESS_PASSWORD:-}
WORDPRESS_EMAIL=${WORDPRESS_EMAIL:-admin@example.com}
WORDPRESS_SCHEME=${WORDPRESS_SCHEME:-http}
WORDPRESS_HOST=${WORDPRESS_HOST:-localhost}
WORDPRESS_SKIP_INSTALL=${WORDPRESS_SKIP_INSTALL:-no}

# [DEBUG] Log env vars (mask password for security)
echo "[DEBUG] WORDPRESS_DB_HOST=$WORDPRESS_DB_HOST"
echo "[DEBUG] WORDPRESS_DB_NAME=$WORDPRESS_DB_NAME"
echo "[DEBUG] WORDPRESS_DB_USER=$WORDPRESS_DB_USER"
echo "[DEBUG] WORDPRESS_DB_PASSWORD=[masked]"
echo "[DEBUG] WORDPRESS_TABLE_PREFIX=$WORDPRESS_TABLE_PREFIX"
echo "[DEBUG] WORDPRESS_BLOG_NAME=$WORDPRESS_BLOG_NAME"
echo "[DEBUG] WORDPRESS_USERNAME=$WORDPRESS_USERNAME"
echo "[DEBUG] WORDPRESS_PASSWORD=[masked]"
echo "[DEBUG] WORDPRESS_EMAIL=$WORDPRESS_EMAIL"
echo "[DEBUG] WORDPRESS_SCHEME=$WORDPRESS_SCHEME"
echo "[DEBUG] WORDPRESS_HOST=$WORDPRESS_HOST"
echo "[DEBUG] WORDPRESS_SKIP_INSTALL=$WORDPRESS_SKIP_INSTALL"

# [DEBUG] Validate critical env vars
if [ -z "$WORDPRESS_DB_PASSWORD" ]; then
	echo >&2 "[DEBUG] WARNING: WORDPRESS_DB_PASSWORD is empty"
fi

cd /opt/app-root/src/wordpress-src/
echo "[DEBUG] Changed to directory: $PWD"

# Function to wait for database
wait_for_db() {
	local max_attempts=30
	local attempt=1
	echo "[DEBUG] Waiting for database connection (host: $WORDPRESS_DB_HOST:3306)"
	while ! /usr/local/bin/wp db query "SELECT 1" --skip-column-names --silent >/dev/null 2>&1; do
		if [ $attempt -eq $max_attempts ]; then
			echo >&2 "[DEBUG] ERROR: Database connection failed after $max_attempts attempts"
			echo >&2 "[DEBUG] Attempted host: $WORDPRESS_DB_HOST:3306, user: $WORDPRESS_DB_USER"
			exit 1
		fi
		echo >&2 "[DEBUG] Waiting for database... (attempt $attempt/$max_attempts)"
		sleep 5
		((attempt++))
	done
	echo "[DEBUG] Database connection established"
}

# [DEBUG] Directory listing
echo "[DEBUG] Current directory contents:"
ls -al

# Generate wp-config.php if it doesn't exist
if [ ! -f wp-config.php ]; then
	echo "[DEBUG] wp-config.php not found, generating..."
	if [ ! -f wp-config-docker.php ]; then
		echo >&2 "[DEBUG] ERROR: wp-config-docker.php not found in $PWD"
		exit 1
	fi
	cp wp-config-docker.php wp-config.php
	echo "[DEBUG] Copied wp-config-docker.php to wp-config.php"

	# [DEBUG] Optional: Uncomment for verbose tracing of wp config commands
	# set -x

	# Set database details
	echo "[DEBUG] Setting wp-config.php database parameters..."
	/usr/local/bin/wp config set DB_NAME "$WORDPRESS_DB_NAME" --allow-root
	/usr/local/bin/wp config set DB_USER "$WORDPRESS_DB_USER" --allow-root
	/usr/local/bin/wp config set DB_PASSWORD "$WORDPRESS_DB_PASSWORD" --allow-root
	/usr/local/bin/wp config set DB_HOST "$WORDPRESS_DB_HOST:3306" --allow-root
	/usr/local/bin/wp config set TABLE_PREFIX "$WORDPRESS_TABLE_PREFIX" --allow-root
	/usr/local/bin/wp config set DB_CHARSET "utf8" --allow-root

	# Fetch authentication keys dynamically
	echo "[DEBUG] Fetching WordPress salts..."
	curl -s https://api.wordpress.org/secret-key/1.1/salt/ | /usr/local/bin/wp config shuffle-salts --allow-root

	chmod 644 wp-config.php
	echo "[DEBUG] Set wp-config.php permissions to 644"
	# set +x  # End verbose tracing if enabled
else
	echo "[DEBUG] wp-config.php already exists, skipping generation"
fi

# Auto-install WordPress if not skipped and DB password is set
if [ "$WORDPRESS_SKIP_INSTALL" = "no" ] && [ -n "$WORDPRESS_DB_PASSWORD" ]; then
	echo "[DEBUG] Preparing to install WordPress..."
	wait_for_db
	echo "[DEBUG] Running wp core install with URL: $WORDPRESS_SCHEME://$WORDPRESS_HOST"
	# [DEBUG] Optional: Uncomment for verbose tracing
	# set -x
	if /usr/local/bin/wp core install \
		--url="$WORDPRESS_SCHEME://$WORDPRESS_HOST" \
		--title="$WORDPRESS_BLOG_NAME" \
		--admin_user="$WORDPRESS_USERNAME" \
		--admin_password="$WORDPRESS_PASSWORD" \
		--admin_email="$WORDPRESS_EMAIL" \
		--allow-root; then
		echo "[DEBUG] WordPress installation completed successfully"
	else
		echo >&2 "[DEBUG] ERROR: WordPress installation failed; check WP-CLI output"
	fi
	# set +x  # End verbose tracing if enabled
else
	echo "[DEBUG] Skipping WordPress installation (WORDPRESS_SKIP_INSTALL=$WORDPRESS_SKIP_INSTALL, DB_PASSWORD length=${#WORDPRESS_DB_PASSWORD})"
fi

# Fix permissions post-config
#echo "[DEBUG] Setting permissions on /opt/app-root/src/wordpress-src/"
#chown -R 1001:0 /opt/app-root/src/wordpress-src/
#find /opt/app-root/src/wordpress-src/ -type d -exec chmod 755 {} +
#find /opt/app-root/src/wordpress-src/ -type f -exec chmod 644 {} +
#echo "[DEBUG] Permissions set: chown 1001:0, dirs 755, files 644"

# [DEBUG] Log final command
echo "[DEBUG] Executing final command before exiting entrypoint.sh script: $@"
# Verify httpd command
if [[ "$1" == "/usr/sbin/httpd" ]]; then
	echo "[DEBUG] Starting Apache in foreground"
	exec "$@"
else
	echo >&2 "[DEBUG] ERROR: Expected /usr/sbin/httpd as first argument, got: $1"
	exit 1
fi