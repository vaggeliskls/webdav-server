#!/bin/sh
set -e

# Function to uncomment a block in a file based on a dynamic block name
uncomment_block() {
    local block_name="$1"
    sed -i "/# ${block_name}_START/,/# ${block_name}_END/ s/^# //" "/usr/local/apache2/conf/webdav.conf"
}

# Function to comment a block in a file based on a dynamic block name
comment_block() {
    local block_name="$1"
    sed -i "/# ${block_name}_START/,/# ${block_name}_END/ s/^[^#]/# &/" "/usr/local/apache2/conf/webdav.conf"
}

envsubst < /usr/local/apache2/conf/webdav.conf.template > /usr/local/apache2/conf/webdav.conf
envsubst < /usr/local/apache2/conf/virtualhost.conf.template > /usr/local/apache2/conf/virtualhost.conf

comment_block "OAUTH_BLOCK"
comment_block "LDAP_BLOCK"
comment_block "BASIC_BLOCK"
comment_block "PUBLIC_BLOCK"

if [ "$LDAP_ENABLED" = "true" ]; then 
    echo "--> LDAP is enabled"; 
    uncomment_block "LDAP_BLOCK"
elif [ "$OAUTH_ENABLED" = "true" ]; then
    echo "--> OAUTH is enabled"; 
    uncomment_block "OAUTH_BLOCK"
elif [ "$BASIC_AUTH_ENABLED" = "true" ]; then
    echo "--> Basic Auth is enabled"; 
    uncomment_block "BASIC_BLOCK"
    # Prepare the password file
    touch "/var/lib/dav/user.passwd"
    echo "$BASIC_USERS" | tr ' ' '\n' | while IFS=':' read -r USERNAME PASSWORD; do
        HASH="`printf '%s' "$USERNAME:$BASIC_AUTH_REALM:$PASSWORD" | md5sum | awk '{print $1}'`"
        printf '%s\n' "$USERNAME:$BASIC_AUTH_REALM:$HASH" >> /var/lib/dav/user.passwd
    done
else
    echo "--> No Authentication is enabled"; 
    uncomment_block "PUBLIC_BLOCK"
fi

# mkdir -p /test
# cp /usr/local/apache2/conf/webdav.conf /test/webdav.conf

echo "Include conf/webdav.conf" >> /usr/local/apache2/conf/httpd.conf
echo "Include conf/virtualhost.conf" >> /usr/local/apache2/conf/httpd.conf
rm -rf /usr/local/apache2/conf/*.template

exec "$@"