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
```python
import base64, json

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsImV4cCI6MTcxMTI2NzIwMH0.abc123"

header_b64, payload_b64, signature = token.split(".")

# base64url decode (pad to multiple of 4)
def decode_part(part):
    padded = part + "=" * (4 - len(part) % 4)
    return json.loads(base64.urlsafe_b64decode(padded))

print(decode_part(header_b64))   # {"alg": "HS256", "typ": "JWT"}
print(decode_part(payload_b64))  # {"sub": "42", "exp": 1711267200}
# signature is binary — only valid if you have the secret to verify it
```

### Issuing and validating with PyJWT
```python
import jwt
from datetime import datetime, timedelta, timezone

SECRET = "your-256-bit-secret"

# Issue
token = jwt.encode(
    {
        "sub": "42",
        "iss": "my-api",
        "aud": "my-client",
        "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        "roles": ["editor"]  # custom claim
    },
    SECRET,
    algorithm="HS256"
)

# Validate — raises DecodeError or ExpiredSignatureError on failure
payload = jwt.decode(
    token,
    SECRET,
    algorithms=["HS256"],
    audience="my-client",  # must validate audience explicitly
    issuer="my-api"
)
print(payload["sub"])  # "42"
```

### RS256 — asymmetric signing (production preferred)
```python
from cryptography.hazmat.primitives import serialization

# Sign with private key (auth server only has this)
with open("private.pem", "rb") as f:
    private_key = serialization.load_pem_private_key(f.read(), password=None)

token = jwt.encode({"sub": "42", "exp": ...}, private_key, algorithm="RS256")

# Verify with public key (any service can have this — no secret to share)
with open("public.pem", "rb") as f:
    public_key = serialization.load_pem_public_key(f.read())

payload = jwt.decode(token, public_key, algorithms=["RS256"], audience="...")
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