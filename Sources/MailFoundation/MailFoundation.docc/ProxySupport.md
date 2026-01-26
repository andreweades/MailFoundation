# Proxy Support

Connect to mail servers through SOCKS5, SOCKS4, and HTTP proxies.

## Overview

MailFoundation supports connecting to mail servers through various proxy protocols. This is essential for applications that need to operate in restricted network environments, preserve user privacy, or access internal mail servers through a gateway.

The library provides a unified `ProxySettings` configuration that works across all supported protocols (IMAP, SMTP, POP3).

## Supported Proxy Types

| Type | Description | Authentication | Use Case |
|------|-------------|----------------|----------|
| **SOCKS5** | The most capable proxy protocol. Supports TCP/UDP, IPv6, and authentication. | Username / Password | Preferred for general proxying and Tor. |
| **SOCKS4/4a** | Older protocol. Supports TCP. SOCKS4a adds remote DNS resolution. | User ID (no password) | Legacy systems. |
| **HTTP CONNECT** | Tunnels TCP through an HTTP proxy. | Basic Auth | Corporate firewalls, HTTPS proxies. |

## Configuring a SOCKS5 Proxy

To use a SOCKS5 proxy, create a ``ProxySettings`` instance and pass it to the session factory method.

```swift
import MailFoundation

// 1. Configure the proxy
let proxy = ProxySettings(
    host: "127.0.0.1",
    port: 9050,             // e.g., Tor default port
    type: .socks5,
    username: "optional_user",
    password: "optional_password"
)

// 2. Connect using the proxy
let session = try await AsyncImapSession.make(
    host: "imap.example.com",
    port: 993,
    backend: .network,
    proxy: proxy            // Pass the proxy settings here
)

// 3. Use the session normally
try await session.connect()
// ...
```

### Remote DNS Resolution

By default, SOCKS5 and SOCKS4a proxies perform DNS resolution on the proxy server. This is critical for privacy (preventing DNS leaks) and for accessing internal hostnames that cannot be resolved locally.

MailFoundation automatically handles this by passing the hostname to the proxy client.

## HTTP CONNECT Proxies

For environments behind corporate firewalls that only allow HTTP traffic, use `.httpConnect`.

```swift
let proxy = ProxySettings(
    host: "proxy.corporate.com",
    port: 8080,
    type: .httpConnect,
    username: "corp_user",
    password: "corp_password"
)
```

## See Also

- ``ProxySettings``
- ``ProxyType``
- ``AsyncTransportFactory``
