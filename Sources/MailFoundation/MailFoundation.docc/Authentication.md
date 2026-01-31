# Authentication

Configure authentication for IMAP, SMTP, and POP3 connections.

## Overview

MailFoundation supports multiple authentication mechanisms to work with different mail servers. This guide covers username/password authentication, OAuth2, and SASL mechanisms.

## Basic Username/Password Authentication

The simplest authentication method uses a username and password:

```swift
// IMAP
let imapStore = try ImapMailStore.make(host: "imap.example.com", port: 993, useTls: true)
try imapStore.connect()
try imapStore.authenticate(username: "user@example.com", password: "password")

// SMTP
let smtpTransport = try SmtpTransport.make(host: "smtp.example.com", port: 587)
try smtpTransport.connect()
try smtpTransport.authenticate(username: "user@example.com", password: "password")

// POP3
let pop3Store = try Pop3MailStore.make(host: "pop.example.com", port: 995, useTls: true)
try pop3Store.connect()
try pop3Store.authenticate(username: "user@example.com", password: "password")
```

## OAuth2 Authentication

For Gmail, Microsoft 365, and other OAuth2 providers, use XOAUTH2:

```swift
// Obtain an access token from your OAuth2 provider
let accessToken = "ya29.a0AfH6SMB..."

// IMAP with OAuth2
let imapStore = try ImapMailStore.make(host: "imap.gmail.com", port: 993, useTls: true)
try imapStore.connect()
try imapStore.authenticateOAuth2(username: "user@gmail.com", accessToken: accessToken)

// SMTP with OAuth2
let smtpTransport = try SmtpTransport.make(host: "smtp.gmail.com", port: 587)
try smtpTransport.connect()
try smtpTransport.authenticateOAuth2(username: "user@gmail.com", accessToken: accessToken)
```

### Gmail OAuth2 Setup

To use OAuth2 with Gmail:

1. Create a project in the [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the Gmail API
3. Create OAuth2 credentials (Client ID and Secret)
4. Request the `https://mail.google.com/` scope
5. Exchange the authorization code for access and refresh tokens

### Microsoft 365 OAuth2 Setup

For Microsoft 365 (Exchange Online):

1. Register an application in [Azure Portal](https://portal.azure.com/)
2. Configure API permissions for IMAP/SMTP
3. Use scopes like `https://outlook.office365.com/IMAP.AccessAsUser.All`
4. Follow the OAuth2 authorization code flow

## SASL Mechanisms

MailFoundation supports several SASL authentication mechanisms:

| Mechanism | Security | Description |
|-----------|----------|-------------|
| SCRAM-SHA-512-PLUS | High | SCRAM-SHA-512 with TLS channel binding (RFC 5802/5929) |
| SCRAM-SHA-256-PLUS | High | SCRAM-SHA-256 with TLS channel binding (RFC 7677/5929) |
| SCRAM-SHA-1-PLUS | High | SCRAM-SHA-1 with TLS channel binding (RFC 5802/5929) |
| SCRAM-SHA-512 | High | Salted challenge-response with SHA-512 (RFC 7677) |
| SCRAM-SHA-256 | High | Salted challenge-response with SHA-256 (RFC 7677) |
| SCRAM-SHA-1 | High | Salted challenge-response with SHA-1 (RFC 5802) |
| GSSAPI | High | Kerberos authentication (enterprise environments) |
| NTLM | Medium | Microsoft challenge-response (Exchange servers) |
| CRAM-MD5 | Medium | Challenge-response with MD5 |
| PLAIN | Low | Sends credentials in base64 (use with TLS) |
| LOGIN | Low | Legacy two-step authentication |
| XOAUTH2 | High | OAuth2 bearer token |

The library automatically selects the most secure mechanism available, preferring SCRAM-PLUS variants when TLS channel binding is available:

```swift
// The session will negotiate the best available mechanism
// Preference order (when channel binding is available):
// SCRAM-SHA-512-PLUS > SCRAM-SHA-256-PLUS > SCRAM-SHA-1-PLUS > SCRAM-SHA-512 > SCRAM-SHA-256 > SCRAM-SHA-1
// > GSSAPI > NTLM > CRAM-MD5 > PLAIN > LOGIN
try session.authenticate(username: "user", password: "pass")
```

To use a specific mechanism:

```swift
// Force CRAM-MD5
try session.authenticate(
    username: "user",
    password: "pass",
    mechanism: .cramMd5
)
```

## SCRAM Authentication

SCRAM (Salted Challenge Response Authentication Mechanism) is the recommended authentication method when OAuth2 is not available. It provides strong security guarantees:

- **Password is never sent** - Only cryptographic proofs are exchanged
- **Salted password hashing** - Uses PBKDF2 to protect against rainbow table attacks
- **Mutual authentication** - Server proves it knows the password too
- **Replay protection** - Each authentication uses a unique nonce

### Using SCRAM Directly

```swift
// IMAP with SCRAM-SHA-256
let auth = ImapSasl.scramSha256(username: "user@example.com", password: "secret")
try session.authenticate(auth)

// SMTP with SCRAM-SHA-512 (strongest variant)
let auth = SmtpSasl.scramSha512(username: "user@example.com", password: "secret")
try session.authenticate(auth)

// POP3 with SCRAM-SHA-1 (for older servers)
let auth = Pop3Sasl.scramSha1(username: "user@example.com", password: "secret")
try session.authenticate(auth)
```

### SCRAM-PLUS (Channel Binding)

SCRAM-PLUS binds the authentication to the TLS channel, protecting against
credential forwarding attacks on TLS-terminating proxies. When TLS channel
binding data is available, MailFoundation will automatically prefer SCRAM-PLUS
mechanisms during `authenticateSasl`.

You can also pass channel binding explicitly:

```swift
// Use channel binding from a STARTTLS-capable transport (tls-server-end-point)
if let tlsTransport = transport as? StartTlsTransport,
   let binding = tlsTransport.scramChannelBinding {
    let auth = ImapSasl.scramSha256Plus(
        username: "user@example.com",
        password: "secret",
        channelBinding: binding
    )
    try session.authenticate(auth)
}
```

For async transports:

```swift
if let tlsTransport = transport as? AsyncStartTlsTransport,
   let binding = await tlsTransport.scramChannelBinding {
    let auth = ImapSasl.scramSha256Plus(
        username: "user@example.com",
        password: "secret",
        channelBinding: binding
    )
    try await session.authenticate(auth)
}
```

### SCRAM Variants

Choose the appropriate SCRAM variant based on server support:

| Variant | Hash Size | Recommendation |
|---------|-----------|----------------|
| SCRAM-SHA-512-PLUS | 512 bits | Best security when channel binding is available |
| SCRAM-SHA-256-PLUS | 256 bits | Recommended when server supports SCRAM-PLUS |
| SCRAM-SHA-1-PLUS | 160 bits | Legacy channel-binding variant |
| SCRAM-SHA-512 | 512 bits | Best security, use when available |
| SCRAM-SHA-256 | 256 bits | Good security, widely supported |
| SCRAM-SHA-1 | 160 bits | Legacy, use only if others unavailable |

```swift
// Check which mechanisms the server supports
let capabilities = session.capabilities

if capabilities.contains(.authScramSha512) {
    let auth = ImapSasl.scramSha512(username: user, password: pass)
    try session.authenticate(auth)
} else if capabilities.contains(.authScramSha256) {
    let auth = ImapSasl.scramSha256(username: user, password: pass)
    try session.authenticate(auth)
} else if capabilities.contains(.authScramSha1) {
    let auth = ImapSasl.scramSha1(username: user, password: pass)
    try session.authenticate(auth)
}
```

### SCRAM Protocol Flow

Understanding the SCRAM authentication flow:

1. **Client Initial Message** - Client sends username and a random nonce
2. **Server Challenge** - Server responds with salt, iteration count, and combined nonce
3. **Client Proof** - Client computes PBKDF2 hash and sends cryptographic proof
4. **Server Verification** - Server verifies client and sends its own signature
5. **Client Verification** - Client verifies server's signature (mutual authentication)

```swift
// Low-level SCRAM usage with ScramContext
let context = ScramContext(
    username: "user",
    password: "pencil",
    algorithm: .sha256
)

// Step 1: Get initial message to send to server
let initialMessage = try context.getInitialMessage()

// Step 2: Process server's challenge and generate response
let clientResponse = try context.processChallenge(serverFirstMessage)

// Step 3: Verify server's final message
try context.verifyServerSignature(serverFinalMessage)

// Authentication complete
print("Authenticated: \(context.isAuthenticated)")
```

## GSSAPI/Kerberos Authentication

For enterprise environments using Active Directory or Kerberos:

```swift
// IMAP with GSSAPI (uses system Kerberos credentials)
if let auth = ImapSasl.gssapi(host: "mail.corp.example.com") {
    try session.authenticate(auth)
}

// With explicit credentials (if not using system credential cache)
if let auth = ImapSasl.gssapi(
    host: "mail.corp.example.com",
    username: "user@CORP.EXAMPLE.COM",
    password: "password"
) {
    try session.authenticate(auth)
}
```

> Note: GSSAPI requires macOS/iOS with the GSS framework and valid Kerberos credentials.

## NTLM Authentication

For Microsoft Exchange servers that don't support modern authentication:

```swift
// NTLM with domain from username
let auth = ImapSasl.ntlm(
    username: "DOMAIN\\user",  // or user@domain.com
    password: "secret"
)
try session.authenticate(auth)

// NTLM with explicit domain
let auth = SmtpSasl.ntlm(
    username: "user",
    password: "secret",
    domain: "CORP",
    workstation: "WORKSTATION01"
)
try session.authenticate(auth)
```

## POP3 APOP Authentication

POP3 servers may support APOP (Authenticated Post Office Protocol), which avoids sending passwords in cleartext:

```swift
let session = Pop3Session(transport: transport)
try session.connect()

// Check if APOP is available (server sends a timestamp in greeting)
if session.supportsApop {
    try session.authenticateApop(username: "user", password: "pass")
} else {
    try session.authenticate(username: "user", password: "pass")
}
```

## TLS and Security

Always use TLS to protect credentials in transit:

```swift
// Implicit TLS (port 993 for IMAP, 995 for POP3, 465 for SMTP)
let store = try ImapMailStore.make(
    host: "imap.example.com",
    port: 993,
    useTls: true
)

// STARTTLS (upgrade connection after connecting)
let store = try ImapMailStore.make(
    host: "imap.example.com",
    port: 143,
    useTls: false  // Connect plain, then upgrade
)
try store.connect()
try store.startTls()  // Upgrade to TLS
try store.authenticate(username: "user", password: "pass")
```

### TLS Configuration

Customize TLS settings for specific requirements:

```swift
let tlsConfig = TlsConfiguration(
    minProtocolVersion: .tlsv12,
    maxProtocolVersion: .tlsv13,
    validateCertificates: true
)

let store = try ImapMailStore.make(
    host: "imap.example.com",
    port: 993,
    useTls: true,
    tlsConfiguration: tlsConfig
)
```

### Certificate Validation

For self-signed certificates or custom CAs:

```swift
let tlsConfig = TlsConfiguration(
    validateCertificates: false  // Disable validation (not recommended for production)
)

// Or provide a custom validation callback
let tlsConfig = TlsConfiguration(
    certificateValidator: { context in
        // Custom validation logic
        return true  // Accept certificate
    }
)
```

## Server Capabilities

Check what authentication mechanisms a server supports:

```swift
// IMAP
let session = ImapSession(transport: transport)
try session.connect()
let capabilities = session.capabilities

if capabilities.contains(.authPlain) {
    print("Server supports PLAIN authentication")
}
if capabilities.contains(.authXOAuth2) {
    print("Server supports OAuth2")
}

// SMTP
let smtpSession = SmtpSession(transport: transport)
try smtpSession.connect()
try smtpSession.ehlo(domain: "client.example.com")

if smtpSession.capabilities.contains(.authPlain) {
    print("SMTP server supports PLAIN")
}
```

## Error Handling

Handle authentication failures gracefully:

```swift
do {
    try store.authenticate(username: "user", password: "wrong")
} catch let error as SessionError {
    switch error {
    case .authenticationFailed(let message):
        print("Authentication failed: \(message)")
    case .notConnected:
        print("Not connected to server")
    default:
        print("Session error: \(error)")
    }
}
```

## Best Practices

1. **Always use TLS** - Never send credentials over unencrypted connections
2. **Prefer OAuth2** - When available, OAuth2 is more secure than passwords
3. **Store credentials securely** - Use Keychain on Apple platforms
4. **Handle token refresh** - OAuth2 tokens expire; implement refresh logic
5. **Check capabilities first** - Verify the server supports your auth method
6. **Use app-specific passwords** - For accounts with 2FA enabled
