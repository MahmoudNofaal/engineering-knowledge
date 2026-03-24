# Secret Management

> The practice of storing, accessing, rotating, and auditing sensitive credentials — API keys, database passwords, certificates — in a way that keeps them out of code and minimizes exposure.

---

## When To Use It

The moment your application needs a credential that isn't a user's own password, you need secret management. Environment variables in a `.env` file are the minimum viable step up from hardcoded strings, but they're not enough for production. Use a dedicated secrets manager when you have multiple environments, multiple services, rotation requirements, or compliance obligations. The rule is simple: secrets do not belong in source control, ever — not even in private repos.

---

## Core Concept

The core problem is that code needs credentials to run, but credentials in code get leaked — through git history, logs, error messages, or stolen laptops. The solution is to separate where secrets are stored (a vault or secrets manager) from where code runs. At startup, the application authenticates to the secrets manager using a machine identity (an IAM role, a managed identity, a Vault AppRole) and fetches the credentials it needs. The secrets manager provides audit logs, rotation, access control, and versioning. The application never holds the secret longer than necessary and never persists it to disk.

---

## The Code

### Fetching a secret from AWS Secrets Manager (C#)
```csharp
using Amazon.SecretsManager;
using Amazon.SecretsManager.Model;

public async Task<string> GetSecretAsync(string secretName)
{
    var client = new AmazonSecretsManagerClient(); // uses IAM role — no hardcoded keys
    var request = new GetSecretValueRequest { SecretId = secretName };
    var response = await client.GetSecretValueAsync(request);
    return response.SecretString; // e.g. {"username":"admin","password":"s3cr3t"}
}
```

### Loading secrets into ASP.NET Core configuration
```csharp
// Program.cs — pull secrets at startup, inject via IConfiguration
builder.Configuration.AddSecretsManager(configurator: options =>
{
    // Map secret name "prod/myapp/db" → config key "ConnectionStrings:Default"
    options.SecretFilter = entry => entry.Name.StartsWith("prod/myapp/");
    options.KeyGenerator = (entry, key) => key.Replace("prod/myapp/", "").Replace("/", ":");
});

// Now use it normally — secret value is never in code or config files
var connStr = builder.Configuration.GetConnectionString("db");
```

### HashiCorp Vault — fetching a secret (Python)
```python
import hvac

# Vault auth via AppRole (machine identity — no human password needed)
client = hvac.Client(url="https://vault.internal:8200")
client.auth.approle.login(
    role_id="my-role-id",
    secret_id="my-secret-id"  # injected at deploy time, not hardcoded
)

secret = client.secrets.kv.v2.read_secret_version(
    path="myapp/database",
    mount_point="secret"
)
password = secret["data"]["data"]["password"]
```

### Detecting leaked secrets in git (pre-commit hook)
```bash
# Install truffleHog or gitleaks as a pre-commit hook
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
```

---

## Gotchas

- **Secrets in git history survive deletion** — `git rm` doesn't remove a secret from history. You need `git filter-repo` or BFG Repo Cleaner, and then you must rotate the secret immediately because it may have already been cloned.
- **Environment variables leak into child processes and crash dumps** — they're better than hardcoded strings, but they appear in `/proc/<pid>/environ` on Linux, in process listings, and in some APM tools. Don't treat them as fully secure.
- **Secret rotation requires application cooperation** — rotating a DB password is only safe if the application can reload credentials without restarting. Design for dynamic secret loading from the start, not as an afterthought.
- **Over-privileged machine identities are the new shared password** — if every service uses the same IAM role with access to all secrets, a compromised service reaches everything. Apply least-privilege to machine identities exactly as you would to human users.
- **Logging secrets in error handling is extremely common** — `catch (Exception e) { _logger.LogError(e.Message); }` sounds safe, but if the exception message includes connection string details (which many DB drivers include), you're logging secrets. Use structured logging and sanitize exception messages.

---

## Interview Angle

**What they're really testing:** Whether you've thought about the operational security of credentials beyond just "don't hardcode them."

**Common question form:** "How do you manage secrets in a production environment?" or "A developer accidentally committed an API key — what do you do?"

**The depth signal:** A junior says "use environment variables and don't commit secrets." A senior describes a full secrets lifecycle: storage in a vault, machine identity authentication (not static keys), rotation without downtime, audit logging, and incident response for a leaked secret (rotate immediately, audit access logs, scan git history). A senior also knows that environment variables are not the end state — they're a step, not a solution.

---

## Related Topics

- [[system-design/api-security.md]] — Secrets management protects the credentials your API uses to authenticate to other systems.
- [[devops/docker-secrets.md]] — Container secrets have specific patterns; environment variables in Docker have well-known pitfalls.
- [[system-design/authentication-patterns.md]] — Machine-to-machine auth (what secrets enable) is distinct from user auth.

---

## Source

https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html

---

*Last updated: 2026-03-24*