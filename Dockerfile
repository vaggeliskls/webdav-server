FROM httpd:2.4

# Metadata labels
LABEL maintainer="vaggeliskls <https://github.com/vaggeliskls>"
LABEL description="A WebDAV server running on Apache httpd, configured for non-root execution."
LABEL build_date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
LABEL license="MIT"

# Install gettext for envsubst
RUN apt-get update && apt-get install -y gettext-base libapache2-mod-auth-openidc

# Create a non-root user and group
RUN groupadd -r webuser && useradd -r -g webuser webuser

# Create necessary directories and adjust ownership
RUN mkdir -p "/var/www/html" && \
    mkdir -p "/var/lib/dav/data" && \
    chown -R webuser:webuser "/var/www/html" "/var/lib/dav" "/usr/local/apache2"

# Uncomment necessary LoadModule lines in httpd.conf
RUN for i in \
    authn_core authn_file authz_core authz_user \
    ldap authnz_ldap ssl auth_basic \
    alias headers mime setenvif \
    dav dav_fs; \
    do \
    sed -i -e "/^#LoadModule ${i}_module.*/s/^#//" /usr/local/apache2/conf/httpd.conf; \
    done

# Enable Icons    
RUN sed -i '/httpd-autoindex.conf/s/^#//' conf/httpd.conf;

# Copy the new configuration files into the container
COPY ./webdav.conf /usr/local/apache2/conf/webdav.conf.template
COPY ./virtualhost.conf /usr/local/apache2/conf/virtualhost.conf.template

# Change ports in the Apache configuration to higher ports
# Suppress the "could not determine FQDN" startup warning
RUN sed -i 's/Listen 80/Listen 8080/' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's/Listen 443/Listen 8443/' /usr/local/apache2/conf/httpd.conf && \
    echo "ServerName localhost" >> /usr/local/apache2/conf/httpd.conf

# Copy the entrypoint script into the container
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose the new higher ports
EXPOSE 8080/tcp 8443/tcp
# Switch to the non-root user
USER webuser
ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "httpd-foreground" ]
