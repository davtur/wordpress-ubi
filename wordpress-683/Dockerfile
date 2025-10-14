FROM registry.access.redhat.com/ubi9/php-83

LABEL maintainer="David Turner" \
      description="WordPress on UBI9 with PHP 8.3 and Apache for OpenShift"

USER root

# Enable UBI 9 repositories and install dependencies
RUN dnf install -y --enablerepo=ubi-9-baseos-rpms \
          --enablerepo=ubi-9-appstream-rpms \
          --enablerepo=ubi-9-codeready-builder-rpms \
          --setopt=install_weak_deps=0 php-gd php-mbstring php-intl \
          php-pecl-zip php-bcmath php-mysqlnd php-xml php-process mod_ssl openssl && \
          dnf clean all && \
          rm -rf /var/cache/dnf

# Configure Apache for HTTPS on 8443 and HTTP on 8080, set ServerName
RUN mkdir -p /etc/pki/tls/certs /etc/pki/tls/private /var/log/httpd && \
    chown 1001:0 /etc/pki/tls/certs /etc/pki/tls/private /var/log/httpd && \
    chmod 755 /etc/pki/tls/certs /var/log/httpd && \
    chmod 750 /etc/pki/tls/private && \
    # Generate self-signed SSL certificates for testing
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/pki/tls/private/server.key \
        -out /etc/pki/tls/certs/server.crt \
        -subj "/CN=localhost" && \
    chown 1001:0 /etc/pki/tls/certs/server.crt /etc/pki/tls/private/server.key && \
    chmod 644 /etc/pki/tls/certs/server.crt && \
    chmod 640 /etc/pki/tls/private/server.key && \
    # Clear default httpd.conf and add required directives
    echo "" > /etc/httpd/conf/httpd.conf && \
    # Add MPM, ServerName, Listen, and VirtualHost directives
    { \
        echo '# Disable other MPMs to ensure prefork is used'; \
        echo '# LoadModule mpm_event_module modules/mod_mpm_event.so'; \
        echo '# LoadModule mpm_worker_module modules/mod_mpm_worker.so'; \
        echo '# LoadModule heartmonitor_module modules/mod_heartmonitor.so'; \
        echo 'LoadModule mpm_prefork_module modules/mod_mpm_prefork.so'; \
        echo 'LoadModule php_module modules/libphp.so'; \
        echo 'ServerName localhost'; \
        echo 'Listen 8080'; \
        echo 'Listen 8443 https'; \
        echo 'Include conf.d/*.conf'; \
        echo '<VirtualHost *:8080>'; \
        echo '    DocumentRoot "/opt/app-root/src/wordpress-src"'; \
        echo '    <Directory "/opt/app-root/src/wordpress-src">'; \
        echo '        AllowOverride All'; \
        echo '        Require all granted'; \
        echo '    </Directory>'; \
        echo '</VirtualHost>'; \
    } >> /etc/httpd/conf/httpd.conf && \
    # Clear default conf.d files to avoid conflicts
    rm -f /etc/httpd/conf.d/*.conf && \
    # Create HTTPS VirtualHost configuration
    { \
        echo 'SSLSessionCache shmcb:/run/httpd/sslcache(512000)'; \
        echo 'SSLSessionCacheTimeout 300'; \
        echo '<VirtualHost *:8443>'; \
        echo '    SSLEngine on'; \
        echo '    SSLCertificateFile /etc/pki/tls/certs/server.crt'; \
        echo '    SSLCertificateKeyFile /etc/pki/tls/private/server.key'; \
        echo '    DocumentRoot "/opt/app-root/src/wordpress-src"'; \
        echo '    <Directory "/opt/app-root/src/wordpress-src">'; \
        echo '        AllowOverride All'; \
        echo '        Require all granted'; \
        echo '    </Directory>'; \
        echo '</VirtualHost>'; \
    } >> /etc/httpd/conf.d/ssl.conf

# Recommended opcache settings for WordPress
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=60'; \
    } > /etc/php.d/opcache-recommended.ini

ENV WORDPRESS_VERSION=6.8.3 \
    WORDPRESS_SHA1=fd56bcdc15f1877e45dce67942ea75949ed650e8

# Download and verify WordPress
RUN set -eux; \
    curl -o /tmp/wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
    echo "${WORDPRESS_SHA1} */tmp/wordpress.tar.gz" | sha1sum -c -; \
    mkdir -p /opt/app-root/src/wordpress-src; \
    tar -xzf /tmp/wordpress.tar.gz -C /opt/app-root/src/wordpress-src --strip-components=1; \
    rm /tmp/wordpress.tar.gz; \
    chown -R 1001:0 /opt/app-root/src/wordpress-src; \
    mkdir -p /opt/app-root/src/wordpress-src/wp-content/upgrades; \
    chown -R 1001:0 /opt/app-root/src/wordpress-src/wp-content/upgrades

# Copy entrypoint and config template
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY wp-config-docker.php /opt/app-root/src/wordpress-src/wp-config-docker.php

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown 1001:0 /usr/local/bin/docker-entrypoint.sh /opt/app-root/src/wordpress-src/wp-config-docker.php && \
    chown -R 1001:0 /var/log/httpd && \
    chmod -R 775 /var/log/httpd

# Web root volume for persistence
VOLUME /opt/app-root/src

# OpenShift-compatible non-root user and ports
USER 1001
EXPOSE 8080 8443

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/usr/sbin/httpd", "-DFOREGROUND"]