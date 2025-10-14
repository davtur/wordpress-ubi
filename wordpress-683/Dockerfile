FROM registry.access.redhat.com/ubi9/php-83

LABEL maintainer="David Turner" \
      description="WordPress on UBI9 with PHP 8.3 and Apache for OpenShift"

USER root

# Enable UBI 9 repositories and install dependencies
# Install additional PHP extensions required for WordPress and mod_ssl for HTTPS
RUN dnf install -y --enablerepo=ubi-9-baseos-rpms \
          --enablerepo=ubi-9-appstream-rpms \
          --enablerepo=ubi-9-codeready-builder-rpms \
          --setopt=install_weak_deps=0 php-gd php-mbstring php-intl \
          php-pecl-zip php-bcmath php-mysqlnd php-xml php-process mod_ssl && \
          dnf clean all && \
          rm -rf /var/cache/dnf

# Configure Apache for HTTPS on 8443
RUN mkdir -p /etc/pki/tls/certs /etc/pki/tls/private && \
    chown 1001:0 /etc/pki/tls/certs /etc/pki/tls/private && \
    chmod 755 /etc/pki/tls/certs && \
    chmod 750 /etc/pki/tls/private && \
    { \
        echo 'Listen 8080'; \
        echo 'Listen 8443 https'; \
    } >> /etc/httpd/conf/httpd.conf && \
    # Override default SSL cert paths to dummies or customs, then add your VH \
    sed -i 's|^SSLCertificateFile.*|SSLCertificateFile /etc/pki/tls/certs/server.crt|' /etc/httpd/conf.d/ssl.conf && \
    sed -i 's|^SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/pki/tls/private/server.key|' /etc/httpd/conf.d/ssl.conf && \
    { \
        echo '<VirtualHost *:8443>'; \
        echo '    SSLEngine on'; \
        echo '    SSLCertificateFile /etc/pki/tls/certs/server.crt'; \
        echo '    SSLCertificateKeyFile /etc/pki/tls/private/server.key'; \
        echo '    DocumentRoot "/opt/app-root/src"'; \
        echo '    <Directory "/opt/app-root/src">'; \
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
# Update to exact SHA1 for your version if needed
# get the sha1 for tar.gz from https://wordpress.org/download/releases/

# Download and verify WordPress, stage in /opt/app-root/src/wordpress-src
RUN set -eux; \
    curl -o /tmp/wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
    echo "${WORDPRESS_SHA1} */tmp/wordpress.tar.gz" | sha1sum -c -; \
    mkdir -p /opt/app-root/src/wordpress-src; \
    tar -xzf /tmp/wordpress.tar.gz -C /opt/app-root/src/wordpress-src --strip-components=1; \
    rm /tmp/wordpress.tar.gz; \
    chown -R 1001:0 /opt/app-root/src/wordpress-src; \
    mkdir -p /opt/app-root/src/wordpress-src/wp-content/upgrades; \
    chown -R 1001:0 /opt/app-root/src/wordpress-src/wp-content/upgrades

# Copy entrypoint and config template (adapt paths for UBI)
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY wp-config-docker.php /opt/app-root/src/wordpress-src/wp-config-docker.php

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown 1001:0 /usr/local/bin/docker-entrypoint.sh /opt/app-root/src/wordpress-src/wp-config-docker.php

# Web root volume for persistence
VOLUME /opt/app-root/src

# OpenShift-compatible non-root user and ports (expose both HTTP and HTTPS)
USER 1001
EXPOSE 8080 8443

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/usr/sbin/httpd", "-DFOREGROUND"]