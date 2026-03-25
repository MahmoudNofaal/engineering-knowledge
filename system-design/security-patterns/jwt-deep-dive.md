# JWT Deep Dive

> A JSON Web Token is a compact, self-contained, cryptographically signed token that carries claims — allowing any party with the public key to verify it without calling the issuer.

---

## When To Use It

Use JWTs as access tokens in stateless APIs where you don't want server-side session state, and as ID tokens in OIDC flows to carry verified identity claims. Don't use JWTs to store sensitive data — they're encoded, not encrypted (unless you use JWE). Don't use them as long-lived session tokens without a revocation strategy. JWTs trade the ability to revoke tokens before expiry for the ability to validate them without network calls.

---

## Core Concept

A JWT is three base64url-encoded JSON objects joined by dots: `header.payload.signature`. The header says which algorithm was used to sign it. The payload contains claims — `sub` (subject/user ID), `exp` (expiry), `iss` (issuer), `aud` (audience), plus any custom claims you add. The signature is a cryptographic hash of `header.payload` using a secret (HMAC) or private key (RSA/ECDSA). Anyone with the secret or public key can verify the signature — meaning the payload hasn't been tampered with — without contacting the issuer. That's the whole value proposition: stateless verification. The catch is that a valid, unrevoked token works until `exp`, even if you've deleted the user.

---

## The Code

### Decoding a JWT manually (understanding the structure)
```csharp
using System;
using System.Text;
using System.Text.Json;

public class TokenParser
{
    public void DecodeJwtManually()
    {
        var token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsImV4cCI6MTcxMTI2NzIwMH0.abc123";

        var parts = token.Split(".");
        var headerB64 = parts[0];
        var payloadB64 = parts[1];
        var signature = parts[2];

        var header = DecodePart(headerB64);
        var payload = DecodePart(payloadB64);

        Console.WriteLine(header);    // {{\"alg\": \"HS256\", \"typ\": \"JWT\"}}
        Console.WriteLine(payload);   // {{\"sub\": \"42\", \"exp\": 1711267200}}
        // signature is binary — only valid if you have the secret to verify it
    }

    private string DecodePart(string part)
    {
        // Pad to multiple of 4
        var padded = part + new string('=', (4 - part.Length % 4) % 4);
        var decoded = Convert.FromBase64String(padded.Replace('-', '+').Replace('_', '/'));
        return Encoding.UTF8.GetString(decoded);
    }
}
```

### Issuing and validating with System.IdentityModel.Tokens.Jwt
```csharp
using System;
using System.IdentityModel.Tokens.Jwt;
using System.Collections.Generic;
using Microsoft.IdentityModel.Tokens;

public class JwtHandler
{
    private const string Secret = "your-256-bit-secret-key-here-1234567890ab";

    public string IssueJwt()
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Secret));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: "my-api",
            audience: "my-client",
            claims: new List<System.Security.Claims.Claim>
            {
                new System.Security.Claims.Claim("sub", "42"),
                new System.Security.Claims.Claim("roles", "editor")
            },
            expires: DateTime.UtcNow.AddHours(1),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public System.Security.Claims.ClaimsPrincipal ValidateJwt(string token)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Secret));
        var handler = new JwtSecurityTokenHandler();

        var principal = handler.ValidateToken(token, new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = key,
            ValidateIssuer = true,
            ValidIssuer = "my-api",
            ValidateAudience = true,
            ValidAudience = "my-client",
            ValidateLifetime = true
        }, out SecurityToken validatedToken);

        return principal;
    }
}
```

### RS256 — asymmetric signing (production preferred)
```csharp
using System.Security.Cryptography;
using System.IdentityModel.Tokens.Jwt;
using System.Collections.Generic;
using Microsoft.IdentityModel.Tokens;
using System;

public class RsaJwtHandler
{
    public string IssueRsaJwt(RSAParameters privateKey)
    {
        var rsa = new RSACryptoServiceProvider();
        rsa.ImportParameters(privateKey);

        var key = new RsaSecurityKey(rsa);
        var credentials = new SigningCredentials(key, SecurityAlgorithms.RsaSha256);

        var token = new JwtSecurityToken(
            issuer: "my-api",
            audience: "my-client",
            claims: new List<System.Security.Claims.Claim>
            {
                new System.Security.Claims.Claim("sub", "42")
            },
            expires: DateTime.UtcNow.AddHours(1),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public System.Security.Claims.ClaimsPrincipal ValidateRsaJwt(string token, RSAParameters publicKey)
    {
        var rsa = new RSACryptoServiceProvider();
        rsa.ImportParameters(publicKey);

        var key = new RsaSecurityKey(rsa);
        var handler = new JwtSecurityTokenHandler();

        var principal = handler.ValidateToken(token, new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = key,
            ValidateIssuer = true,
            ValidIssuer = "my-api",
            ValidateAudience = true,
            ValidAudience = "my-client",
            ValidateLifetime = true
        }, out SecurityToken validatedToken);

        return principal;
    }
}
```

---

## Gotchas

- **`alg: none` is a real attack vector** — some early JWT libraries accepted tokens with `alg: none` in the header, skipping signature verification entirely. Always whitelist algorithms explicitly; never trust the `alg` header blindly.
- **The payload is public** — base64 is not encryption. Anyone who intercepts the token can read every claim. Never put passwords, PII, or secrets in JWT claims unless you're using JWE (JSON Web Encryption).
- **Not validating `aud` and `iss` is a common bug** — a token issued for your staging environment is technically valid on production if you only check the signature. Always validate issuer and audience.
- **Clock skew breaks expiry validation in distributed systems** — if server clocks differ by more than a few seconds, a just-expired token gets rejected or a just-issued token gets an `nbf` error. Most libraries have a `leeway` parameter — use it.
- **Long expiry + no revocation = permanent access after account deletion** — a 24-hour JWT issued to a user you've banned at hour 1 is still valid for 23 more hours. Short expiry (15 minutes) + refresh token rotation is the production answer.

---

## Interview Angle

**What they're really testing:** Whether you understand the structure and security properties of JWTs, not just how to paste a library call.

**Common question form:** "How does JWT authentication work?" or "What are the security risks of JWTs?"

**The depth signal:** A junior says "the token is signed so you know it's valid." A senior explains the three-part structure, the difference between HS256 and RS256 (and why RS256 is preferred in microservices — you don't share a secret), the revocation problem with concrete mitigations, and the `alg: none` vulnerability. A senior also knows the difference between JWS (signed) and JWE (encrypted).

---

## Related Topics

- [[system-design/oauth2-openid.md]] — JWTs are the token format used in OIDC ID tokens and commonly in OAuth2 access tokens.
- [[system-design/authentication-patterns.md]] — JWT is one authentication mechanism; understand where it fits in the broader landscape.
- [[system-design/api-security.md]] — JWT validation is a component of API security, not the whole picture.

---

## Source

https://jwt.io/introduction

---

*Last updated: 2026-03-24*