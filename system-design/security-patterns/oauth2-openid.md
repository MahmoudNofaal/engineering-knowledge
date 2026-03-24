# OAuth2 & OpenID Connect

> OAuth2 is a protocol for delegated authorization (letting a third party act on your behalf); OpenID Connect (OIDC) is a thin identity layer on top of it that adds authentication.

---

## When To Use It

Use OAuth2 when you need to let users grant your app access to resources in another system (Google Drive, GitHub, Stripe) without sharing their password. Use OIDC when you want to delegate authentication entirely — let Google or Azure AD verify the user's identity and hand you a verified token. Don't roll your own OAuth2 server unless you're building an identity platform — use a managed provider (Auth0, Keycloak, Azure AD, Cognito) and implement the client side only.

---

## Core Concept

OAuth2 defines flows ("grants") for how a client gets an access token from an authorization server. The key insight is that the user never gives your app their password — they authenticate directly with the authorization server, which then issues your app a scoped token. OAuth2 alone only tells you that a token is valid and what it's allowed to do; it says nothing about who the user is. OIDC fixes that by adding an ID token (a JWT) that contains identity claims — name, email, subject ID. The authorization code flow with PKCE is the correct flow for nearly all modern apps: browser-based, mobile, and server-side.

---

## The Code

### Authorization Code Flow with PKCE (client side, JavaScript)
```javascript
// Step 1: Generate PKCE code verifier and challenge
const codeVerifier = crypto.randomUUID() + crypto.randomUUID(); // 64 chars
const encoder = new TextEncoder();
const data = encoder.encode(codeVerifier);
const digest = await crypto.subtle.digest("SHA-256", data);
const codeChallenge = btoa(String.fromCharCode(...new Uint8Array(digest)))
  .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

sessionStorage.setItem("pkce_verifier", codeVerifier);

// Step 2: Redirect user to authorization server
const params = new URLSearchParams({
  response_type: "code",
  client_id: "my-client-id",
  redirect_uri: "https://myapp.com/callback",
  scope: "openid email profile",
  code_challenge: codeChallenge,
  code_challenge_method: "S256",
  state: crypto.randomUUID() // CSRF protection
});

window.location.href = `https://auth.example.com/authorize?${params}`;
```

### Exchanging the code for tokens (server side, C#)
```csharp
// Step 3: Auth server redirects back with ?code=xxx
// Exchange code + verifier for tokens
public async Task<TokenResponse> ExchangeCodeAsync(string code, string verifier)
{
    using var http = new HttpClient();
    var response = await http.PostAsync("https://auth.example.com/token",
        new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"]    = "authorization_code",
            ["code"]          = code,
            ["redirect_uri"]  = "https://myapp.com/callback",
            ["client_id"]     = "my-client-id",
            ["code_verifier"] = verifier  // server validates against challenge
        }));

    return await response.Content.ReadFromJsonAsync<TokenResponse>();
    // TokenResponse contains: access_token, id_token, refresh_token, expires_in
}
```

### Validating the ID token (OIDC)
```csharp
// The ID token is a JWT — validate signature, issuer, audience, expiry
var handler = new JwtSecurityTokenHandler();
var validationParams = new TokenValidationParameters
{
    ValidIssuer   = "https://auth.example.com",
    ValidAudience = "my-client-id",
    // Fetch JWKS (public keys) from issuer's /.well-known/jwks.json
    IssuerSigningKeys = await FetchJwksAsync("https://auth.example.com/.well-known/jwks.json")
};

var principal = handler.ValidateToken(idToken, validationParams, out _);
var email = principal.FindFirst("email")?.Value;
```

---

## Gotchas

- **OAuth2 is not authentication — it's authorization** — an access token proves the user granted your app some permissions, not that the user is who they say they are. You need OIDC (the ID token) for that distinction.
- **Never use the implicit flow** — it was deprecated in OAuth 2.1. It returns tokens in the URL fragment, which gets logged in browser history and server logs. Always use authorization code + PKCE.
- **State parameter is not optional** — it's CSRF protection. If you don't validate that the state in the callback matches what you sent, an attacker can inject their own authorization code.
- **Access tokens should not be parsed by resource servers in OIDC flows** — the resource server should treat them as opaque and call the introspection endpoint, or validate them as JWTs using the provider's public keys. Don't trust claims you decode yourself without signature validation.
- **Refresh token rotation must be enforced** — every time a refresh token is used, issue a new one and invalidate the old one. If an old refresh token is used after rotation, it signals theft — invalidate the entire token family.

---

## Interview Angle

**What they're really testing:** Whether you understand delegated authorization vs authentication and can describe a secure token flow end to end.

**Common question form:** "How does 'Sign in with Google' work under the hood?" or "Explain the OAuth2 authorization code flow."

**The depth signal:** A junior describes OAuth as "using Google to log in." A senior explains the authorization code + PKCE flow step by step, distinguishes OAuth2 from OIDC, explains why PKCE replaces client secrets for public clients, and knows the difference between the ID token (identity) and access token (authorization). A senior also knows about the /.well-known/openid-configuration discovery endpoint.

---

## Related Topics

- [[system-design/authentication-patterns.md]] — OAuth2/OIDC is one of several authentication patterns; understand the landscape first.
- [[system-design/jwt-deep-dive.md]] — ID tokens and access tokens are JWTs; you need to understand JWT internals to validate them correctly.
- [[system-design/api-security.md]] — Access tokens are the primary mechanism for securing API endpoints.

---

## Source

https://oauth.net/2/

---

*Last updated: 2026-03-24*