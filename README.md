# 🌐 Simple & Powerful WebDAV Server

The **WebDAV Server** is a lightweight, customizable solution built with Docker, designed for secure file sharing and remote access. It offers flexible configuration options and supports multiple authentication methods, including basic authentication, LDAP, and OAuth. With minimal setup, this server is ideal for both personal and enterprise use cases where easy deployment and secure access are key.


> [!NOTE]
> The pre-built Docker image is available at:  **`ghcr.io/vaggeliskls/webdav-server:latest`**

## 📦 Prerequisites

Before getting started, make sure you have the following:

- **Docker** version **20.0** or higher
- Basic knowledge of Docker and WebDAV

## 🚀 Key Features

- **Effortless Deployment**: Set up a fully operational WebDAV server quickly using Docker.
- **Flexible Authentication**:
  - Basic Authentication 🛡️
  - LDAP Authentication 🛡️
  - OAuth Authentication 🛡️
- **Proxy-Ready**: Easily integrate with reverse proxies to add more authentication layers.
- **Authentication is Optional**: The server runs without authentication by default, allowing flexibility for your setup.

## 🔧 Authentication Setup

You can enable various authentication mechanisms using environment variables in a `.env` file. Here’s how to configure each one:

### 🔐 Basic Authentication

To enable basic authentication with username and password protection:

```bash
BASIC_AUTH_ENABLED=true
BASIC_AUTH_REALM=WebDAV
BASIC_USERS=alice:alice123 bob:bob123
```

### 🔐 OAuth Authentication
OAuth authentication (example with Keycloak) configuration:
```
OAUTH_ENABLED=true
OIDCProviderMetadataURL="http://keycloak/keycloak-auth/realms/master/.well-known/openid-configuration"
OIDCRedirectURI="http://my-domain.local/redirect_uri"
OIDCDefaultURL="http://my-domain.local"
OIDCCryptoPassphrase="randomly_generated_secure_passphrase"
OIDCClientID="webdav-client"
OIDCClientSecret="ABC123def456GHI789jkl0mnopqrs"
OIDCProviderTokenEndpointAuth="client_secret_basic"
OIDCRemoteUserClaim="preferred_username"
OIDCScope="openid email profile"
OIDCXForwardedHeaders="X-Forwarded-Host"
```

### 🔐 LDAP Authentication
LDAP integration for centralized user management:
```
LDAP_ENABLED=true
LDAP_URL=ldaps://ldap.example.com
LDAP_ATTRIBUTE=uid
LDAP_BASE_DN=ou=users,dc=example,dc=com
LDAP_BIND_DN=uid=admin,ou=users,dc=example,dc=com
LDAP_BIND_PASSWORD=securepassword
```

## 📖 Usage Guide

1. Clone Repository

2. Start the WebDAV Server: `docker compose up --build`

3. Open http://localhost or your server's IP in a browser or WebDAV client to start using the service.


## 📚 References

- [Docker Apache WebDAV](https://github.com/mgutt/docker-apachewebdav)
- [What is WebDAV?](https://www.jscape.com/blog/what-is-webdav)