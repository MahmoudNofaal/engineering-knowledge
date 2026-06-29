# Domain 9 — Production Engineering

## Phonebook

**~475 topics across 22 groups.** Priority 1 = Critical → Priority 4 = Reference | `[ ]` = not generated | `[x]` = generated

**Scope note:** This domain teaches hands-on procedure — commands, manifests, pipelines, troubleshooting. Architectural concepts (what Kubernetes is, what CAP theorem means, when to choose microservices) live in **Domain 7**. If a topic here starts explaining "why," it's drifted out of scope — it should explain "how."

---

## Group A — Git Fundamentals (9.001–9.025)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.001|Git Init, Clone, and Remote Basics|1|[ ]|
|9.002|Git Add, Commit, and the Staging Area|1|[ ]|
|9.003|Git Status and Diff — Reading the Working Tree|1|[ ]|
|9.004|Git Log — Filtering and Formatting History|1|[ ]|
|9.005|Git Branch — Create, Switch, Delete|1|[ ]|
|9.006|Git Merge — Fast-Forward vs Three-Way|1|[ ]|
|9.007|Resolving Merge Conflicts — Manual Workflow|1|[ ]|
|9.008|Git Push and Pull — Tracking Branches|1|[ ]|
|9.009|Git Fetch vs Pull — What Actually Happens|1|[ ]|
|9.010|.gitignore — Patterns and Common .NET Templates|2|[ ]|
|9.011|Git Tags — Lightweight vs Annotated|2|[ ]|
|9.012|Git Remote Management — Multiple Remotes|2|[ ]|
|9.013|Undoing Changes — Checkout, Restore, Revert|1|[ ]|
|9.014|Git Reset — Soft, Mixed, Hard|1|[ ]|
|9.015|Git Clean — Removing Untracked Files Safely|2|[ ]|
|9.016|Git Stash — Save, Pop, Apply, Drop|1|[ ]|
|9.017|Git Show and Blame — Inspecting History|2|[ ]|
|9.018|.gitattributes — Line Endings and Diff Behavior|2|[ ]|
|9.019|Git Config — Global, Local, and System Scope|2|[ ]|
|9.020|SSH Keys for Git — Setup and Multiple Identities|2|[ ]|
|9.021|Git Hooks — pre-commit and pre-push Basics|2|[ ]|
|9.022|Cloning Strategies — Shallow Clones and Sparse Checkout|3|[ ]|
|9.023|Git LFS — Large File Storage Setup|3|[ ]|
|9.024|Renaming and Moving Files — Git Tracking Behavior|2|[ ]|
|9.025|Git Aliases — Custom Shortcuts in .gitconfig|2|[ ]|

**Cross-references:** `9.007` → `7.917 — Trunk-Based Development` (the policy this procedure supports) | `9.014` → `9.013` (reset vs restore decision) | `9.021` → `9.146 — Pre-Commit Hook for dotnet format` (concrete implementation)

---

## Group B — Git Advanced (9.026–9.050)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.026|Interactive Rebase — Squash, Reword, Drop|1|[ ]|
|9.027|Rebase vs Merge — Choosing the Workflow|1|[ ]|
|9.028|Resolving Rebase Conflicts Step-by-Step|1|[ ]|
|9.029|Git Cherry-Pick — Porting Specific Commits|2|[ ]|
|9.030|Git Bisect — Finding the Commit That Broke Things|1|[ ]|
|9.031|Git Reflog — Recovering "Lost" Commits|1|[ ]|
|9.032|Git Worktrees — Multiple Checkouts of One Repo|2|[ ]|
|9.033|Git Submodules — Add, Update, Remove|3|[ ]|
|9.034|Git Subtree — Alternative to Submodules|3|[ ]|
|9.035|Amending Commits — Safe vs Unsafe Scenarios|1|[ ]|
|9.036|Force Push — Risks and Safer Alternatives (--force-with-lease)|1|[ ]|
|9.037|Rewriting History — filter-branch and filter-repo|3|[ ]|
|9.038|Git Rerere — Reusing Recorded Conflict Resolutions|3|[ ]|
|9.039|Splitting a Commit — Interactive Rebase Edit|2|[ ]|
|9.040|Combining Commits Across Branches|2|[ ]|
|9.041|Git Diff Strategies — Word Diff, Stat, Name-Only|2|[ ]|
|9.042|Finding Who Introduced a Bug — Blame and Log -S|2|[ ]|
|9.043|Git Worktree for Hotfix Workflows|2|[ ]|
|9.044|Detached HEAD State — What It Means and Recovery|2|[ ]|
|9.045|Git Patch Files — Format-Patch and Apply|3|[ ]|
|9.046|Resolving "Diverged Branches" Cleanly|1|[ ]|
|9.047|Git Stash with Conflicts — Advanced Recovery|2|[ ]|
|9.048|Monorepo Git Strategies — Sparse Checkout at Scale|3|[ ]|
|9.049|Signing Commits — GPG and SSH Signatures|3|[ ]|
|9.050|Git Performance — Large Repo Optimization (gc, maintenance)|3|[ ]|

**Cross-references:** `9.026` → `9.027` (the most common interview pairing) | `9.030` → `9.031` (bisect often needs reflog to recover) | `9.036` → `7.921 — Branch Protection Rules` (the policy that prevents this from being catastrophic)

---

## Group C — GitHub Workflow (9.051–9.075)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.051|Creating and Reviewing Pull Requests|1|[ ]|
|9.052|PR Description Templates — Writing Effective Ones|2|[ ]|
|9.053|Resolving Conflicts in a PR via GitHub UI|1|[ ]|
|9.054|GitHub CLI (gh) — PR and Issue Workflow|2|[ ]|
|9.055|GitHub CLI — Authenticating and Switching Accounts|2|[ ]|
|9.056|CODEOWNERS — Automatic Review Assignment|2|[ ]|
|9.057|Draft PRs — When and Why to Use Them|2|[ ]|
|9.058|Squash Merge vs Merge Commit vs Rebase Merge on GitHub|1|[ ]|
|9.059|GitHub Issues — Labels, Milestones, Linking to PRs|2|[ ]|
|9.060|GitHub Projects — Kanban Board Setup|3|[ ]|
|9.061|Suggested Changes in PR Reviews|2|[ ]|
|9.062|Re-Requesting Review After Changes|2|[ ]|
|9.063|GitHub Discussions vs Issues — When to Use Each|3|[ ]|
|9.064|Protected Branches — Configuring Required Checks|2|[ ]|
|9.065|GitHub Actions Status Checks Blocking Merge|2|[ ]|
|9.066|Forking Workflow — Contributing to External Repos|2|[ ]|
|9.067|Syncing a Fork with Upstream|2|[ ]|
|9.068|GitHub Releases — Tagging and Release Notes|2|[ ]|
|9.069|Auto-Generated Release Notes from PRs|3|[ ]|
|9.070|GitHub Webhooks — Setup and Common Use Cases|3|[ ]|
|9.071|Dependabot — Configuring Automated Dependency PRs|2|[ ]|
|9.072|GitHub Security Alerts — Triage Workflow|2|[ ]|
|9.073|Resolving "This Branch Has Conflicts" Banner|1|[ ]|
|9.074|GitHub PR Diff Review — Viewing Large Diffs Efficiently|2|[ ]|
|9.075|Linking Commits to Issues — Closing Keywords|2|[ ]|

**Cross-references:** `9.058` → `7.918/919/920 — Branching strategies` (which merge style fits which strategy) | `9.064` → `9.065` (branch protection + CI status checks work together) | `9.071` → `7.940 — Dependency Scanning` (concept this automates)

---

## Group D — Terminal and Shell (9.076–9.095)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.076|Navigating the Filesystem Efficiently — cd, pushd, popd|2|[ ]|
|9.077|Bash vs Zsh vs PowerShell — Picking a Daily Shell|2|[ ]|
|9.078|Piping and Redirection — \|, >, >>, 2>&1|1|[ ]|
|9.079|grep, find, and xargs — Searching Effectively|1|[ ]|
|9.080|sed and awk — Quick Text Transformation|2|[ ]|
|9.081|Environment Variables — Setting, Scoping, .env Files|1|[ ]|
|9.082|Shell History — Search and Reuse (Ctrl+R, history)|2|[ ]|
|9.083|tmux / Screen — Persistent Terminal Sessions|2|[ ]|
|9.084|Dotfiles — Managing .bashrc / .zshrc / Profile.ps1|2|[ ]|
|9.085|Shell Aliases and Functions — Daily Productivity|1|[ ]|
|9.086|curl and httpie — Testing APIs from the Terminal|1|[ ]|
|9.087|jq — Querying JSON from the Command Line|1|[ ]|
|9.088|Process Management — ps, top, kill, nohup|2|[ ]|
|9.089|SSH — Config Files and Connection Shortcuts|2|[ ]|
|9.090|Port Forwarding — Local and Remote SSH Tunnels|2|[ ]|
|9.091|Cron Jobs — Scheduling Recurring Tasks|2|[ ]|
|9.092|Windows Terminal / WSL — Setup for .NET Development|2|[ ]|
|9.093|File Permissions — chmod, chown Basics|2|[ ]|
|9.094|Disk Usage Diagnosis — du, df, ncdu|2|[ ]|
|9.095|Network Diagnosis — netstat, ss, lsof, ping, traceroute|2|[ ]|

**Cross-references:** `9.087` → `9.086` (curl + jq is the standard API debugging pair) | `9.092` → `9.225 — Docker Desktop on Windows` | `9.095` → `9.301 — Diagnosing Connection Refused Errors`

---

## Group E — IDE and Editor Proficiency (9.096–9.115)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.096|VS Code — Essential Keybindings for .NET Development|1|[ ]|
|9.097|VS Code — Multi-Cursor and Column Selection|2|[ ]|
|9.098|VS Code — Debugging C# with launch.json|1|[ ]|
|9.099|VS Code — Integrated Terminal Workflow|2|[ ]|
|9.100|VS Code — Extensions Every .NET Engineer Should Have|2|[ ]|
|9.101|VS Code — Remote Containers / Dev Containers|2|[ ]|
|9.102|JetBrains Rider — Essential Keybindings|2|[ ]|
|9.103|Rider — Debugging and Breakpoint Types|2|[ ]|
|9.104|Rider — Refactoring Shortcuts|2|[ ]|
|9.105|Conditional Breakpoints and Data Breakpoints|2|[ ]|
|9.106|Debugging Across Processes — Attach to Process|2|[ ]|
|9.107|Hot Reload in .NET — Setup and Limitations|2|[ ]|
|9.108|EditorConfig — Enforcing Style Across Editors|2|[ ]|
|9.109|Source Control Integration in the IDE — GitLens / Built-In|2|[ ]|
|9.110|Searching a Large Codebase — Find in Files, Symbol Search|1|[ ]|
|9.111|Go-to-Definition, Find Usages, Call Hierarchy|2|[ ]|
|9.112|Snippets — Creating Custom Code Snippets|3|[ ]|
|9.113|Multi-Root Workspaces in VS Code|3|[ ]|
|9.114|Remote Debugging a Deployed .NET Service|2|[ ]|
|9.115|Memory and CPU Profiling from the IDE|2|[ ]|

**Cross-references:** `9.098` → `9.292 — Remote Debugging in Production` | `9.107` → `9.001 — Daily Dev Loop` | `9.115` → `7.1083/1084 — dotTrace/dotMemory` (architectural context)

---

## Group F — Docker Hands-On (9.116–9.150)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.116|Writing a Basic Dockerfile for ASP.NET Core|1|[ ]|
|9.117|Writing a Multi-Stage Dockerfile — SDK Build, Runtime Final|1|[ ]|
|9.118|Building an Image — docker build Flags and Context|1|[ ]|
|9.119|Running a Container — Ports, Volumes, Env Vars|1|[ ]|
|9.120|docker exec — Shelling into a Running Container|1|[ ]|
|9.121|docker logs — Following and Filtering Output|1|[ ]|
|9.122|Inspecting Image Layers — docker history|2|[ ]|
|9.123|.dockerignore — Writing One for a .NET Solution|1|[ ]|
|9.124|Tagging and Pushing Images to a Registry|1|[ ]|
|9.125|Debugging a Container That Exits Immediately|1|[ ]|
|9.126|Debugging "Cannot Connect to Docker Daemon"|1|[ ]|
|9.127|Reducing Image Size — Alpine, Chiseled, Distroless in Practice|2|[ ]|
|9.128|Writing a HEALTHCHECK Instruction|2|[ ]|
|9.129|Environment-Specific Dockerfiles — Dev vs Prod Targets|2|[ ]|
|9.130|Mounting Volumes for Local Development|2|[ ]|
|9.131|Docker Networking — Bridge Network Hands-On|2|[ ]|
|9.132|Container Resource Limits — --memory and --cpus Flags|2|[ ]|
|9.133|docker cp — Moving Files In and Out of Containers|2|[ ]|
|9.134|Cleaning Up — Pruning Images, Containers, Volumes|2|[ ]|
|9.135|docker stats — Live Resource Monitoring|2|[ ]|
|9.136|Running as Non-Root — Implementing USER in Practice|2|[ ]|
|9.137|Multi-Platform Builds with buildx|3|[ ]|
|9.138|Debugging Slow Docker Builds — Layer Caching in Practice|2|[ ]|
|9.139|Environment Variables vs Secrets in Containers|2|[ ]|
|9.140|Connecting a Containerized App to a Local SQL Server|2|[ ]|
|9.141|Debugging "Port Already in Use"|1|[ ]|
|9.142|docker-compose vs docker compose — CLI Differences|3|[ ]|
|9.143|Container Restart Policies — Practical Configuration|2|[ ]|
|9.144|Image Vulnerability Scanning — docker scout / Trivy Hands-On|2|[ ]|
|9.145|Debugging Build Failures — Layer-by-Layer Isolation|2|[ ]|
|9.146|Writing a Pre-Commit Hook That Lints the Dockerfile|3|[ ]|
|9.147|Copying Only What's Needed — Optimizing COPY Instructions|2|[ ]|
|9.148|Debugging Container DNS Resolution Issues|2|[ ]|
|9.149|Building from a Private NuGet Feed Inside Docker|2|[ ]|
|9.150|Container Image Naming and Versioning Conventions|2|[ ]|

**Cross-references:** `9.117` → `7.849 — Multi-Stage Builds` (concept) | `9.125/9.126/9.141` are the three most common Docker interview troubleshooting scenarios | `9.144` → `7.942 — Container Image Scanning`

---

## Group G — Docker Compose (9.151–9.165)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.151|Writing a docker-compose.yml for an ASP.NET Core + SQL Server Stack|1|[ ]|
|9.152|depends_on and Health-Check-Gated Startup|1|[ ]|
|9.153|Named Volumes vs Bind Mounts in Compose|2|[ ]|
|9.154|Compose Networking — Service Discovery by Name|2|[ ]|
|9.155|Environment Files in Compose — .env Integration|2|[ ]|
|9.156|Compose Override Files — Dev vs Prod Variants|2|[ ]|
|9.157|Scaling Services Locally — docker compose up --scale|3|[ ]|
|9.158|Debugging "Service Unhealthy" in Compose|1|[ ]|
|9.159|Adding Redis and RabbitMQ to a Local Compose Stack|2|[ ]|
|9.160|Compose Profiles — Conditional Service Groups|3|[ ]|
|9.161|Rebuilding a Single Service Without Full Restart|2|[ ]|
|9.162|Viewing Logs Across All Services — compose logs -f|1|[ ]|
|9.163|Compose Down — Cleanup Flags (-v, --remove-orphans)|2|[ ]|
|9.164|Seeding a Local Database on Compose Startup|2|[ ]|
|9.165|Compose for Integration Test Environments|2|[ ]|

**Cross-references:** `9.151` → `9.140 — Connecting App to Local SQL Server` | `9.165` → `8.944/945 — TestContainers` (the alternative approach)

---

## Group H — Kubernetes Hands-On (9.166–9.200)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.166|kubectl Setup — Context, Config, and Namespace Switching|1|[ ]|
|9.167|Writing a Deployment Manifest for a .NET Service|1|[ ]|
|9.168|Writing a Service Manifest — ClusterIP in Practice|1|[ ]|
|9.169|kubectl apply vs create vs replace|1|[ ]|
|9.170|kubectl get, describe, logs — The Daily Loop|1|[ ]|
|9.171|Debugging CrashLoopBackOff Step-by-Step|1|[ ]|
|9.172|Debugging ImagePullBackOff|1|[ ]|
|9.173|Debugging Pending Pods — Resource and Scheduling Issues|1|[ ]|
|9.174|kubectl exec — Shelling into a Pod|1|[ ]|
|9.175|kubectl port-forward — Local Access to a Cluster Service|1|[ ]|
|9.176|Writing a ConfigMap and Mounting It as Env Vars|1|[ ]|
|9.177|Writing a Secret and Mounting It as a Volume|1|[ ]|
|9.178|Writing Liveness and Readiness Probes — Practical YAML|1|[ ]|
|9.179|kubectl rollout status / history / undo|1|[ ]|
|9.180|Editing a Live Resource — kubectl edit and patch|2|[ ]|
|9.181|kubectl logs --previous — Debugging a Crashed Container|1|[ ]|
|9.182|Writing a Job and CronJob Manifest|2|[ ]|
|9.183|Writing an Ingress Manifest — Routing Rules in Practice|2|[ ]|
|9.184|Setting Resource Requests and Limits — Practical Tuning|1|[ ]|
|9.185|Debugging OOMKilled Pods|1|[ ]|
|9.186|kubectl top — Live Resource Usage per Pod/Node|2|[ ]|
|9.187|Writing an HPA Manifest and Watching It Scale|2|[ ]|
|9.188|Namespace Management — Creating and Switching Context|2|[ ]|
|9.189|kubectl diff — Previewing Changes Before Apply|2|[ ]|
|9.190|Debugging a Service with No Endpoints|2|[ ]|
|9.191|kubectl debug — Ephemeral Containers for Troubleshooting|2|[ ]|
|9.192|Writing a StatefulSet for a Stateful Workload|2|[ ]|
|9.193|Draining a Node Safely — cordon and drain|2|[ ]|
|9.194|kubectl get events — Reading the Cluster Event Timeline|1|[ ]|
|9.195|Debugging DNS Resolution Failures Inside a Pod|2|[ ]|
|9.196|Rolling Back a Bad Deployment in Under a Minute|1|[ ]|
|9.197|Writing NetworkPolicy YAML — Practical Lockdown|2|[ ]|
|9.198|kubectl apply -k — Using Kustomize Overlays|2|[ ]|
|9.199|Local Kubernetes — kind / minikube Setup for Dev|2|[ ]|
|9.200|Connecting kubectl to AKS — az aks get-credentials|1|[ ]|

**Cross-references:** `9.171/9.172/9.173/9.185` are the four classic on-call Kubernetes debugging scenarios — every one links to its Domain 7 concept note | `9.167` → `7.868/871 — Pod and Deployment concepts` | `9.196` → `7.873 — Rollback concept`

---

## Group I — Helm (9.201–9.215)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.201|Helm Install, Upgrade, Rollback — Basic Lifecycle|1|[ ]|
|9.202|Writing a Basic Chart — Chart.yaml and values.yaml|1|[ ]|
|9.203|Templating with {{ .Values }} — Practical Patterns|1|[ ]|
|9.204|helm template — Previewing Rendered YAML Locally|2|[ ]|
|9.205|helm diff — Previewing an Upgrade's Impact|2|[ ]|
|9.206|Chart Dependencies — requirements.yaml / Chart.yaml deps|2|[ ]|
|9.207|Helm Hooks — pre-install and post-upgrade in Practice|2|[ ]|
|9.208|Debugging a Failed Helm Release|1|[ ]|
|9.209|helm rollback — Recovering from a Bad Release|1|[ ]|
|9.210|Multiple Values Files — Per-Environment Overrides|1|[ ]|
|9.211|Helm Repositories — Adding and Searching|2|[ ]|
|9.212|Packaging and Versioning a Chart for Release|2|[ ]|
|9.213|Helm Secrets Management — helm-secrets Plugin|3|[ ]|
|9.214|Linting a Chart — helm lint Before Commit|2|[ ]|
|9.215|Testing a Chart — helm test Hooks|3|[ ]|

**Cross-references:** `9.202` → `7.902/903 — Helm chart structure concept` | `9.210` → `9.156 — Compose override pattern` (same idea, different tool)

---

## Group J — CI/CD GitHub Actions Hands-On (9.216–9.245)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.216|Writing a .NET Build-and-Test Workflow from Scratch|1|[ ]|
|9.217|Workflow Triggers in Practice — push, pull_request, workflow_dispatch|1|[ ]|
|9.218|Caching NuGet Packages to Speed Up Builds|1|[ ]|
|9.219|Matrix Builds — Testing Across .NET Versions|2|[ ]|
|9.220|Using Secrets in a Workflow — Practical Setup|1|[ ]|
|9.221|Writing a Docker Build-and-Push Step|1|[ ]|
|9.222|Deploying to Azure App Service via Actions|1|[ ]|
|9.223|Deploying to AKS via Actions — Full Pipeline|2|[ ]|
|9.224|Debugging a Failing Workflow — Reading Logs Effectively|1|[ ]|
|9.225|Re-Running Failed Jobs — Selective Re-Run|1|[ ]|
|9.226|Writing a Reusable Workflow — workflow_call|2|[ ]|
|9.227|Composite Actions — Packaging Repeated Steps|2|[ ]|
|9.228|Conditional Steps — if: Expressions in Practice|2|[ ]|
|9.229|Artifacts — Uploading and Downloading Between Jobs|2|[ ]|
|9.230|Job Dependencies — needs: and Parallel vs Sequential|2|[ ]|
|9.231|Setting Up OIDC for Azure Login (No Stored Credentials)|2|[ ]|
|9.232|Branch-Specific Deployment Logic|2|[ ]|
|9.233|Debugging "Permission Denied" in Actions|1|[ ]|
|9.234|Local Testing of Workflows with act|2|[ ]|
|9.235|Writing a Status Badge for the README|3|[ ]|
|9.236|Environment Protection Rules — Manual Approval Gates|2|[ ]|
|9.237|Publishing Test Results as a PR Check|2|[ ]|
|9.238|Code Coverage Reporting in a Workflow|2|[ ]|
|9.239|Auto-Versioning a Build with GitVersion in Actions|2|[ ]|
|9.240|Debugging Slow Workflows — Identifying the Bottleneck Step|2|[ ]|
|9.241|Self-Hosted Runners — Setup and Use Cases|3|[ ]|
|9.242|Concurrency Control — Cancelling Superseded Runs|2|[ ]|
|9.243|Path Filters — Triggering Only on Relevant Changes|2|[ ]|
|9.244|Writing a Scheduled Workflow (Cron)|2|[ ]|
|9.245|Full End-to-End Pipeline — Build, Test, Scan, Push, Deploy|1|[ ]|

**Cross-references:** `9.216/9.245` are the foundation and capstone of this group | `9.222/9.223` → `7.931/932 — Deploy to App Service/AKS concept` | `9.224` → `9.233` (the two most common "why did my pipeline fail" entry points)

---

## Group K — CI/CD Azure DevOps Hands-On (9.246–9.265)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.246|Writing a YAML Pipeline from Scratch — azure-pipelines.yml|1|[ ]|
|9.247|Stages, Jobs, Steps — Practical Structure|1|[ ]|
|9.248|Variable Groups — Setup and Linking to a Pipeline|1|[ ]|
|9.249|Service Connections — Setting Up Azure Auth|1|[ ]|
|9.250|Approval Gates Between Stages|2|[ ]|
|9.251|Pipeline Templates — Reusing Steps Across Repos|2|[ ]|
|9.252|Debugging a Failed Azure DevOps Run|1|[ ]|
|9.253|Publishing and Consuming Build Artifacts|2|[ ]|
|9.254|Multi-Stage Deployment — Dev → Staging → Prod|2|[ ]|
|9.255|Triggers — Branch Filters and Path Filters|2|[ ]|
|9.256|Task Marketplace — Finding and Using Third-Party Tasks|3|[ ]|
|9.257|Self-Hosted Agents — Setup and Pool Management|3|[ ]|
|9.258|Pipeline Caching — Speeding Up NuGet Restore|2|[ ]|
|9.259|Release Pipelines vs YAML Pipelines — Migration Notes|3|[ ]|
|9.260|Variable Scoping — Pipeline, Stage, Job Level|2|[ ]|
|9.261|Conditional Execution in Azure Pipelines|2|[ ]|
|9.262|Test Results and Code Coverage Publishing|2|[ ]|
|9.263|Deploying to AKS from Azure DevOps|2|[ ]|
|9.264|Manual Validation Tasks for Compliance Gates|3|[ ]|
|9.265|Migrating a GitHub Actions Workflow to Azure DevOps|3|[ ]|

**Cross-references:** `9.246` mirrors `9.216` (same pipeline, different platform — useful side-by-side) | `9.249` → `7.935 — Service Connections concept`

---

## Group L — Observability Implementation (9.266–9.290)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.266|Wiring Serilog into Program.cs from Scratch|1|[ ]|
|9.267|Configuring Serilog Sinks — Console, File, Seq|1|[ ]|
|9.268|Adding a Correlation ID Middleware — Full Implementation|1|[ ]|
|9.269|Structured Logging in Practice — LogContext and Enrichers|1|[ ]|
|9.270|Wiring OpenTelemetry — ActivitySource Setup in .NET|1|[ ]|
|9.271|Exporting Traces to Jaeger — Local Setup|2|[ ]|
|9.272|Exporting to Application Insights — SDK Wiring|1|[ ]|
|9.273|Adding Custom Spans Around a Business Operation|2|[ ]|
|9.274|Wiring Custom Metrics — System.Diagnostics.Metrics in Practice|2|[ ]|
|9.275|Configuring Health Check Endpoints — /health/live and /health/ready|1|[ ]|
|9.276|Adding a Database Health Check|1|[ ]|
|9.277|Adding an External Dependency Health Check|2|[ ]|
|9.278|Setting Up Seq Locally for Log Querying|2|[ ]|
|9.279|Filtering Noisy Logs — Per-Namespace Log Level Configuration|2|[ ]|
|9.280|Redacting Sensitive Data from Logs — Destructuring Policies in Practice|2|[ ]|
|9.281|Local OpenTelemetry Collector Setup|2|[ ]|
|9.282|Debugging "Why Don't I See My Logs"|1|[ ]|
|9.283|Debugging Missing Traces — Context Propagation Issues|2|[ ]|
|9.284|Adding Request/Response Logging Middleware|2|[ ]|
|9.285|Log Sampling Implementation for High-Volume Endpoints|3|[ ]|
|9.286|Wiring MiniProfiler for Local Dev Performance Visibility|2|[ ]|
|9.287|Setting Up Application Insights Live Metrics Stream|2|[ ]|
|9.288|Exception Logging — Capturing Full Context at the Boundary|1|[ ]|
|9.289|Background Service Observability — Logging Long-Running Jobs|2|[ ]|
|9.290|End-to-End Observability Setup for a New Service|1|[ ]|

**Cross-references:** `9.266/267/268/269` are the foundational Serilog implementation chain | `9.270/271/272` are the OpenTelemetry implementation chain | `9.290` ties everything together — capstone | all link to `7.716–7.775` (Domain 7 observability concepts)

---

## Group M — Dashboards and Alerting Hands-On (9.291–9.310)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.291|Building a Grafana Dashboard from Scratch|1|[ ]|
|9.292|Writing a PromQL Query for Request Rate|2|[ ]|
|9.293|Writing a PromQL Query for Error Rate and P99 Latency|2|[ ]|
|9.294|Setting Up Prometheus Scrape Config for a .NET Service|1|[ ]|
|9.295|Writing a Grafana Alert Rule|2|[ ]|
|9.296|Configuring Alertmanager Routing and Silences|2|[ ]|
|9.297|Building an Application Insights Workbook|2|[ ]|
|9.298|Setting Up Azure Monitor Alerts and Action Groups|1|[ ]|
|9.299|Writing a KQL Query for Log Analytics|2|[ ]|
|9.300|Building a Service Health Dashboard — The Four Golden Signals|1|[ ]|
|9.301|Setting Up an On-Call Alert Routing to Slack/Teams|2|[ ]|
|9.302|Reducing Alert Fatigue — Tuning Thresholds in Practice|2|[ ]|
|9.303|Dashboard for Database Performance — Wait Stats Panel|2|[ ]|
|9.304|Setting Up Synthetic/Availability Tests in Application Insights|2|[ ]|
|9.305|Annotating Deployments on a Dashboard|3|[ ]|
|9.306|Debugging "My Metric Isn't Showing Up"|2|[ ]|
|9.307|Setting SLO Burn-Rate Alerts in Practice|2|[ ]|
|9.308|Exporting/Importing Grafana Dashboards as JSON|2|[ ]|
|9.309|Building a Runbook Link Directly into an Alert|2|[ ]|
|9.310|Load Test Result Visualization — k6 + Grafana|2|[ ]|

**Cross-references:** `9.300` → `7.770/771 — RED/USE Method concept` | `9.307` → `7.654 — Error Budget concept` | `9.291–294` form the Grafana/Prometheus hands-on chain

---

## Group N — Azure CLI and Provisioning (9.311–9.335)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.311|az login and Subscription/Tenant Switching|1|[ ]|
|9.312|Creating a Resource Group from the CLI|1|[ ]|
|9.313|Provisioning an App Service Plan and Web App|1|[ ]|
|9.314|Deploying a .NET App via az webapp deploy|1|[ ]|
|9.315|Configuring App Settings and Connection Strings via CLI|1|[ ]|
|9.316|Provisioning Azure SQL Database from the CLI|1|[ ]|
|9.317|Provisioning an AKS Cluster from the CLI|1|[ ]|
|9.318|Provisioning Azure Container Registry and Pushing an Image|1|[ ]|
|9.319|Provisioning Azure Key Vault and Adding a Secret|1|[ ]|
|9.320|Granting Managed Identity Access to Key Vault via CLI|1|[ ]|
|9.321|Provisioning Azure Service Bus — Namespace, Queue, Topic|2|[ ]|
|9.322|Provisioning Azure Cache for Redis|2|[ ]|
|9.323|Provisioning Application Insights and Linking to a Web App|2|[ ]|
|9.324|Setting Up Deployment Slots — Swap Workflow|2|[ ]|
|9.325|Configuring Custom Domains and TLS via CLI|2|[ ]|
|9.326|Querying Resources with az resource list and JMESPath Queries|2|[ ]|
|9.327|Azure CLI Output Formats — table, json, tsv in Scripts|2|[ ]|
|9.328|Debugging "Insufficient Permissions" Errors in Azure CLI|1|[ ]|
|9.329|Tagging Resources for Cost Tracking|2|[ ]|
|9.330|Tearing Down a Resource Group Safely|1|[ ]|
|9.331|Using Azure CLI in a CI Pipeline — Auth Patterns|2|[ ]|
|9.332|Provisioning Azure Front Door from the CLI|3|[ ]|
|9.333|Scripting a Full Environment Setup — az CLI Script End-to-End|1|[ ]|
|9.334|Azure Cloud Shell — When and Why to Use It|3|[ ]|
|9.335|Cost Estimation Before Provisioning — Pricing Calculator Workflow|3|[ ]|

**Cross-references:** `9.333` is the capstone tying the whole group together | `9.319/320` are the most commonly tested pair (Key Vault + Managed Identity setup) | all link to corresponding `7.78X — 7.84X` Azure architecture concepts

---

## Group O — IaC Bicep Hands-On (9.336–9.355)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.336|Writing a Basic Bicep File — Resource Group Scope|1|[ ]|
|9.337|Bicep Parameters and Variables in Practice|1|[ ]|
|9.338|Provisioning an App Service via Bicep|1|[ ]|
|9.339|Provisioning Azure SQL via Bicep|1|[ ]|
|9.340|Bicep Modules — Splitting a Large Template|2|[ ]|
|9.341|Bicep Outputs — Passing Values Between Modules|2|[ ]|
|9.342|What-If Deployments — Previewing Changes|1|[ ]|
|9.343|Deploying Bicep via Azure CLI — az deployment group create|1|[ ]|
|9.344|Deploying Bicep from a GitHub Actions Pipeline|2|[ ]|
|9.345|Debugging a Failed Bicep Deployment|1|[ ]|
|9.346|Bicep Loops — Provisioning Multiple Similar Resources|2|[ ]|
|9.347|Conditional Resource Deployment in Bicep|2|[ ]|
|9.348|Referencing Existing Resources in Bicep|2|[ ]|
|9.349|Bicep Key Vault Reference — Pulling Secrets at Deploy Time|2|[ ]|
|9.350|Decompiling ARM Templates to Bicep|3|[ ]|
|9.351|Bicep Registry — Publishing and Consuming Shared Modules|3|[ ]|
|9.352|Linting Bicep Files Before Deployment|2|[ ]|
|9.353|Managing Multiple Environments with Bicep Parameter Files|1|[ ]|
|9.354|Resource Naming Conventions in Bicep at Scale|2|[ ]|
|9.355|Full Environment-in-a-Box — One Bicep File, Multiple Resources|1|[ ]|

**Cross-references:** `9.355` is the capstone | `9.342` is the most commonly tested safety practice | links to `7.838 — Bicep concept` and the corresponding `9.31X` CLI-provisioning notes for the manual equivalent

---

## Group P — IaC Terraform Hands-On (9.356–9.375)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.356|Writing a Basic Terraform Configuration for Azure|1|[ ]|
|9.357|terraform init, plan, apply — The Core Loop|1|[ ]|
|9.358|Terraform State — Understanding terraform.tfstate|1|[ ]|
|9.359|Remote State — Configuring an Azure Storage Backend|1|[ ]|
|9.360|Terraform Variables and tfvars Files|1|[ ]|
|9.361|Terraform Modules — Writing and Reusing|2|[ ]|
|9.362|Terraform Outputs — Exposing Values for Other Configs|2|[ ]|
|9.363|terraform destroy — Safe Teardown Practices|1|[ ]|
|9.364|Debugging a Failed terraform apply|1|[ ]|
|9.365|State Locking — Preventing Concurrent Apply Conflicts|2|[ ]|
|9.366|terraform import — Bringing Existing Resources Under Management|2|[ ]|
|9.367|Resolving State Drift|2|[ ]|
|9.368|Terraform Workspaces — Managing Multiple Environments|2|[ ]|
|9.369|Provisioning AKS via Terraform|2|[ ]|
|9.370|Terraform in a CI Pipeline — Plan on PR, Apply on Merge|2|[ ]|
|9.371|terraform fmt and validate — Pre-Commit Hygiene|2|[ ]|
|9.372|Sensitive Variables — Marking and Protecting Secrets|1|[ ]|
|9.373|terraform taint / -replace — Forcing Resource Recreation|3|[ ]|
|9.374|Terraform vs Bicep — Hands-On Decision Notes|2|[ ]|
|9.375|Full Environment-in-a-Box — Terraform Equivalent|1|[ ]|

**Cross-references:** `9.375` mirrors `9.355` (Bicep capstone) for direct comparison | `9.358/9.359/9.365/9.367` form the "state management" cluster — the most interview-relevant Terraform subtopic

---

## Group Q — Production Debugging (9.376–9.400)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.376|The First Five Minutes of an Incident — A Practical Checklist|1|[ ]|
|9.377|Diagnosing "Connection Refused" Step-by-Step|1|[ ]|
|9.378|Diagnosing a Service That's Up but Returning 502/504|1|[ ]|
|9.379|Diagnosing High CPU on a Running .NET Process|1|[ ]|
|9.380|Diagnosing a Memory Leak in Production — dotnet-dump Walkthrough|1|[ ]|
|9.381|Diagnosing Thread Pool Starvation in Production|2|[ ]|
|9.382|Capturing a Memory Dump from a Live .NET Process|1|[ ]|
|9.383|Capturing a CPU Trace with dotnet-trace|1|[ ]|
|9.384|Diagnosing a Database Connection Pool Exhaustion Incident|1|[ ]|
|9.385|Diagnosing Slow Requests — Correlating Logs, Traces, Metrics|1|[ ]|
|9.386|Reading a Stack Trace Under Pressure — What to Look At First|1|[ ]|
|9.387|Diagnosing a Deadlock in Production via DMVs|1|[ ]|
|9.388|Diagnosing a Service Stuck in CrashLoopBackOff Mid-Incident|1|[ ]|
|9.389|Diagnosing DNS-Related Outages|2|[ ]|
|9.390|Diagnosing Certificate Expiry Issues|1|[ ]|
|9.391|Tracing a Request End-to-End Across Services|1|[ ]|
|9.392|Rolling Back a Bad Deploy Under Time Pressure|1|[ ]|
|9.393|Diagnosing a Sudden Spike in 4xx Errors|2|[ ]|
|9.394|Diagnosing a Cascading Failure Across Dependent Services|2|[ ]|
|9.395|Reading GC Logs to Confirm a Memory Pressure Hypothesis|2|[ ]|
|9.396|Triage Communication — What to Post in the Incident Channel|2|[ ]|
|9.397|Diagnosing Disk Space Exhaustion on a Production Host|2|[ ]|
|9.398|Diagnosing a Bad Migration That Locked a Production Table|1|[ ]|
|9.399|Writing the Timeline During an Active Incident|2|[ ]|
|9.400|Post-Incident — Capturing Evidence Before It's Lost|2|[ ]|

**Cross-references:** This entire group is the practical counterpart to `7.651–7.690` (Reliability/SLO/Incident Management concepts) | `9.376` is the entry point for every other note in this group | `9.380/382/383` form the diagnostic tooling chain

---

## Group R — Performance Tuning Hands-On (9.401–9.420)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.401|Running a BenchmarkDotNet Benchmark — From Zero to Results|1|[ ]|
|9.402|Profiling a Hot Path with dotnet-trace and Speedscope|1|[ ]|
|9.403|Finding Allocation Hotspots with dotMemory|1|[ ]|
|9.404|Tuning EF Core Query Performance — Step-by-Step Walkthrough|1|[ ]|
|9.405|Adding and Verifying an Index Fix Against a Real Slow Query|1|[ ]|
|9.406|Load Testing a Service with k6 — Writing the First Script|1|[ ]|
|9.407|Load Testing with NBomber — .NET-Native Setup|2|[ ]|
|9.408|Interpreting a Load Test Report — What to Look At First|1|[ ]|
|9.409|Tuning Connection Pool Settings Based on Load Test Results|2|[ ]|
|9.410|Reducing GC Pressure — Before/After with Real Numbers|2|[ ]|
|9.411|Tuning Kestrel Settings for Throughput|2|[ ]|
|9.412|Tuning Thread Pool Settings — MinThreads in Practice|2|[ ]|
|9.413|Caching a Slow Endpoint — From Diagnosis to Fix|1|[ ]|
|9.414|Reducing Payload Size — Compression Setup and Verification|2|[ ]|
|9.415|Diagnosing and Fixing N+1 Queries — Real Before/After|1|[ ]|
|9.416|Tuning HttpClient — Connection Reuse in Practice|2|[ ]|
|9.417|Profiling a Background Job for Throughput Improvements|2|[ ]|
|9.418|Comparing Before/After Performance — Building a Repeatable Test|2|[ ]|
|9.419|Capacity Test — Finding the Breaking Point of a Service|2|[ ]|
|9.420|Writing a Performance Regression Test for CI|2|[ ]|

**Cross-references:** `9.404/405/415` form the EF Core performance debugging chain, paired with Domain 8's `8.354–8.366` execution plan notes | `9.406–408` form the load testing chain

---

## Group S — Incident Response Drills (9.421–9.435)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.421|Running a Tabletop Incident Drill — Format and Roles|2|[ ]|
|9.422|Drill — Database Failover Mid-Traffic|2|[ ]|
|9.423|Drill — Bad Deploy Rollback Under 5 Minutes|1|[ ]|
|9.424|Drill — Diagnosing a Silent Data Corruption Bug|2|[ ]|
|9.425|Drill — Third-Party API Outage — Fallback Activation|2|[ ]|
|9.426|Drill — Secrets Leak — Rotation Under Pressure|2|[ ]|
|9.427|Drill — Certificate Expired in Production|1|[ ]|
|9.428|Drill — Region Failover Exercise|3|[ ]|
|9.429|Writing a Runbook from a Past Incident|2|[ ]|
|9.430|Running a Blameless Post-Mortem Meeting|2|[ ]|
|9.431|Drill — Disk Full on a Production Database Server|2|[ ]|
|9.432|Drill — Sudden Traffic Spike — Scaling Decision Under Pressure|2|[ ]|
|9.433|Game Day Planning — Designing Your Own Chaos Exercise|3|[ ]|
|9.434|On-Call Handoff — What a Good Handoff Looks Like|2|[ ]|
|9.435|Building a Personal Incident Response Checklist|2|[ ]|

**Cross-references:** Every drill links back to its corresponding `9.376–9.400` diagnostic note and its `7.66X–7.69X` Domain 7 concept

---

## Group T — Scripting and Automation (9.436–9.455)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.436|Writing a Bash Deployment Script|1|[ ]|
|9.437|Writing a PowerShell Script for Azure Automation|1|[ ]|
|9.438|Error Handling in Bash Scripts — set -euo pipefail|1|[ ]|
|9.439|Error Handling in PowerShell — Try/Catch and $ErrorActionPreference|2|[ ]|
|9.440|Writing a dotnet CLI Wrapper Script for Common Tasks|2|[ ]|
|9.441|Parsing Command-Line Arguments in Bash|2|[ ]|
|9.442|Writing a Health-Check Polling Script|2|[ ]|
|9.443|Writing a Database Backup Automation Script|2|[ ]|
|9.444|Writing a Log Rotation / Cleanup Script|2|[ ]|
|9.445|Scheduling Scripts — Cron vs Windows Task Scheduler|2|[ ]|
|9.446|Writing a Script That Waits for a Dependency to Be Ready|2|[ ]|
|9.447|Idempotent Scripts — Writing Scripts Safe to Re-Run|1|[ ]|
|9.448|Writing a Makefile for a .NET Project|2|[ ]|
|9.449|Writing a Multi-Step Setup Script for New Developers|1|[ ]|
|9.450|Automating a Repetitive Manual Process — A Worked Example|2|[ ]|
|9.451|Writing a Script to Bulk-Update Kubernetes Resources|2|[ ]|
|9.452|Writing a Script to Tail and Filter Logs Across Pods|2|[ ]|
|9.453|Combining gh CLI and jq for Reporting Scripts|2|[ ]|
|9.454|Writing a Pre-Push Hook That Runs Tests Locally|2|[ ]|
|9.455|Building a Local CLI Tool with dotnet tool install|2|[ ]|

**Cross-references:** `9.447` is the single most important principle across this entire group — cross-reference it from every other note in Group T | `9.436/437` are the foundational bash/PowerShell pair

---

## Group U — Package and Dependency Management (9.456–9.470)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.456|NuGet — Adding, Updating, Removing Packages via CLI|1|[ ]|
|9.457|Central Package Management — Directory.Packages.props|1|[ ]|
|9.458|Resolving NuGet Version Conflicts|1|[ ]|
|9.459|Setting Up a Private NuGet Feed — Azure Artifacts|2|[ ]|
|9.460|dotnet list package --vulnerable — Hands-On Audit|1|[ ]|
|9.461|dotnet list package --outdated — Dependency Health Check|2|[ ]|
|9.462|Locking Package Versions — packages.lock.json|2|[ ]|
|9.463|npm/yarn Basics for a .NET Engineer with a Frontend|2|[ ]|
|9.464|Debugging "Package Downgrade" Warnings|2|[ ]|
|9.465|Restoring Packages in CI — Caching Strategy|2|[ ]|
|9.466|Multi-Targeting a Library — Practical csproj Setup|2|[ ]|
|9.467|Creating and Publishing a NuGet Package|2|[ ]|
|9.468|Debugging Assembly Binding Redirect Issues|3|[ ]|
|9.469|Managing Global.json — Pinning SDK Version per Repo|2|[ ]|
|9.470|Cleaning a Corrupted NuGet Cache|2|[ ]|

**Cross-references:** `9.460` → `7.940 — Dependency Scanning concept` | `9.457` is the modern standard most teams should adopt — flag this in the note's framing

---

## Group V — Environment and Secrets Configuration (9.471–9.485)

|ID|Topic|Priority|Generated|
|---|---|---|---|
|9.471|Configuring appsettings.json per Environment|1|[ ]|
|9.472|dotnet user-secrets — Local Development Workflow|1|[ ]|
|9.473|Reading Secrets from Azure Key Vault in Code|1|[ ]|
|9.474|Configuration Precedence — Debugging "Wrong Value Loaded"|1|[ ]|
|9.475|Setting Environment Variables Across Dev/CI/Prod Consistently|1|[ ]|
|9.476|Using IOptions<T> — Practical Wiring and Validation|2|[ ]|
|9.477|Hot-Reloading Configuration with IOptionsMonitor<T>|2|[ ]|
|9.478|Managing Multiple .env Files for Local Multi-Service Dev|2|[ ]|
|9.479|Rotating a Secret Without Downtime — Practical Steps|2|[ ]|
|9.480|Debugging "Configuration Value Is Null" at Runtime|1|[ ]|
|9.481|Setting Up Feature Flags — Microsoft.FeatureManagement Hands-On|2|[ ]|
|9.482|Auditing What Secrets Exist Across All Environments|2|[ ]|
|9.483|Setting Up Per-Developer Local Secrets Safely|2|[ ]|
|9.484|Migrating Secrets from appsettings.json to Key Vault|1|[ ]|
|9.485|Validating Configuration at Startup — Fail-Fast Pattern|2|[ ]|

**Cross-references:** `9.473/9.484` → `7.822/823 — Key Vault concept` | `9.474/480` are the two most common real-world configuration debugging entry points

---

## Generation Order by Priority — Tier 1 Critical

|#|ID|Topic|
|---|---|---|
|1|9.001|Git Init, Clone, Remote Basics|
|2|9.002|Git Add, Commit, Staging Area|
|3|9.006|Git Merge|
|4|9.007|Resolving Merge Conflicts|
|5|9.013|Undoing Changes|
|6|9.014|Git Reset|
|7|9.016|Git Stash|
|8|9.026|Interactive Rebase|
|9|9.027|Rebase vs Merge|
|10|9.030|Git Bisect|
|11|9.031|Git Reflog|
|12|9.036|Force Push Safety|
|13|9.051|Creating and Reviewing PRs|
|14|9.058|Squash vs Merge Commit|
|15|9.073|Resolving Conflicts Banner|
|16|9.078|Piping and Redirection|
|17|9.079|grep, find, xargs|
|18|9.081|Environment Variables|
|19|9.085|Shell Aliases|
|20|9.086|curl and httpie|
|21|9.087|jq|
|22|9.096|VS Code Keybindings|
|23|9.098|VS Code Debugging|
|24|9.110|Searching a Large Codebase|
|25|9.116|Basic Dockerfile|
|26|9.117|Multi-Stage Dockerfile|
|27|9.118|docker build|
|28|9.119|docker run|
|29|9.120|docker exec|
|30|9.121|docker logs|
|31|9.123|.dockerignore|
|32|9.124|Tagging and Pushing Images|
|33|9.125|Debugging Container Exits|
|34|9.126|Debugging Docker Daemon|
|35|9.141|Port Already in Use|
|36|9.151|docker-compose.yml|
|37|9.152|depends_on Health Checks|
|38|9.158|Service Unhealthy|
|39|9.162|compose logs -f|
|40|9.166|kubectl Setup|
|41|9.167|Deployment Manifest|
|42|9.168|Service Manifest|
|43|9.169|apply vs create vs replace|
|44|9.170|kubectl get/describe/logs|
|45|9.171|CrashLoopBackOff|
|46|9.172|ImagePullBackOff|
|47|9.173|Pending Pods|
|48|9.174|kubectl exec|
|49|9.175|kubectl port-forward|
|50|9.176|ConfigMap|
|51|9.177|Secret|
|52|9.178|Liveness/Readiness Probes|
|53|9.179|rollout status/history/undo|
|54|9.181|logs --previous|
|55|9.184|Resource Requests/Limits|
|56|9.185|OOMKilled|
|57|9.194|kubectl get events|
|58|9.196|Rolling Back a Deployment|
|59|9.200|kubectl + AKS Connection|
|60|9.201|Helm Install/Upgrade/Rollback|
|61|9.202|Writing a Basic Chart|
|62|9.203|Helm Templating|
|63|9.208|Debugging Failed Release|
|64|9.209|helm rollback|
|65|9.210|Multiple Values Files|
|66|9.216|Build-and-Test Workflow|
|67|9.217|Workflow Triggers|
|68|9.218|Caching NuGet|
|69|9.220|Using Secrets in Workflow|
|70|9.221|Docker Build-and-Push Step|
|71|9.222|Deploy to App Service|
|72|9.224|Debugging Failing Workflow|
|73|9.225|Re-Running Failed Jobs|
|74|9.233|Permission Denied in Actions|
|75|9.245|Full End-to-End Pipeline|
|76|9.246|Azure Pipelines YAML|
|77|9.247|Stages, Jobs, Steps|
|78|9.248|Variable Groups|
|79|9.249|Service Connections|
|80|9.252|Debugging Failed Run|
|81|9.266|Wiring Serilog|
|82|9.267|Serilog Sinks|
|83|9.268|Correlation ID Middleware|
|84|9.269|Structured Logging|
|85|9.270|Wiring OpenTelemetry|
|86|9.272|App Insights SDK Wiring|
|87|9.275|Health Check Endpoints|
|88|9.276|Database Health Check|
|89|9.282|Why Don't I See My Logs|
|90|9.288|Exception Logging|
|91|9.290|End-to-End Observability Setup|
|92|9.291|Grafana Dashboard from Scratch|
|93|9.294|Prometheus Scrape Config|
|94|9.298|Azure Monitor Alerts|
|95|9.300|Four Golden Signals Dashboard|
|96|9.311|az login|
|97|9.312|Resource Group from CLI|
|98|9.313|App Service Plan and Web App|
|99|9.314|az webapp deploy|
|100|9.315|App Settings via CLI|
|101|9.316|Azure SQL via CLI|
|102|9.317|AKS Cluster via CLI|
|103|9.318|ACR and Push|
|104|9.319|Key Vault and Secret|
|105|9.320|Managed Identity to Key Vault|
|106|9.328|Insufficient Permissions Errors|
|107|9.330|Tearing Down Resource Group|
|108|9.333|Full Environment Setup Script|
|109|9.336|Basic Bicep File|
|110|9.337|Bicep Parameters/Variables|
|111|9.338|App Service via Bicep|
|112|9.339|Azure SQL via Bicep|
|113|9.342|What-If Deployments|
|114|9.343|Deploying Bicep via CLI|
|115|9.345|Debugging Failed Bicep|
|116|9.353|Multiple Environments — Parameter Files|
|117|9.355|Full Environment-in-a-Box (Bicep)|
|118|9.356|Basic Terraform Config|
|119|9.357|init, plan, apply|
|120|9.358|Terraform State|
|121|9.359|Remote State Backend|
|122|9.360|Variables and tfvars|
|123|9.363|terraform destroy|
|124|9.364|Debugging Failed Apply|
|125|9.372|Sensitive Variables|
|126|9.375|Full Environment-in-a-Box (Terraform)|
|127|9.376|First Five Minutes of an Incident|
|128|9.377|Connection Refused|
|129|9.378|502/504 Diagnosis|
|130|9.379|High CPU Diagnosis|
|131|9.380|Memory Leak — dotnet-dump|
|132|9.382|Capturing a Memory Dump|
|133|9.383|dotnet-trace CPU Trace|
|134|9.384|Connection Pool Exhaustion|
|135|9.385|Correlating Logs/Traces/Metrics|
|136|9.386|Reading a Stack Trace Under Pressure|
|137|9.387|Diagnosing a Deadlock via DMVs|
|138|9.388|CrashLoopBackOff Mid-Incident|
|139|9.390|Certificate Expiry|
|140|9.391|Tracing a Request End-to-End|
|141|9.392|Rolling Back Under Time Pressure|
|142|9.398|Bad Migration Locked a Table|
|143|9.401|Running a BenchmarkDotNet Benchmark|
|144|9.402|Profiling with dotnet-trace/Speedscope|
|145|9.403|Allocation Hotspots — dotMemory|
|146|9.404|Tuning EF Core Query Performance|
|147|9.405|Index Fix Verification|
|148|9.406|Load Testing with k6|
|149|9.408|Interpreting a Load Test Report|
|150|9.413|Caching a Slow Endpoint|
|151|9.415|Diagnosing and Fixing N+1|
|152|9.423|Drill — Rollback Under 5 Minutes|
|153|9.427|Drill — Certificate Expired|
|154|9.436|Bash Deployment Script|
|155|9.437|PowerShell Azure Script|
|156|9.438|Bash Error Handling|
|157|9.447|Idempotent Scripts|
|158|9.449|New Developer Setup Script|
|159|9.456|NuGet CLI Basics|
|160|9.457|Central Package Management|
|161|9.458|Resolving Version Conflicts|
|162|9.460|dotnet list package --vulnerable|
|163|9.471|appsettings.json per Environment|
|164|9.472|dotnet user-secrets|
|165|9.473|Reading Key Vault Secrets in Code|
|166|9.474|Configuration Precedence Debugging|
|167|9.475|Env Vars Across Dev/CI/Prod|
|168|9.480|Configuration Value Is Null|
|169|9.484|Migrating Secrets to Key Vault|

---

_Domain 9 — Production Engineering | ~475 topics | 22 groups | Last updated: June 2026_ _Tags: #engineering #knowledge-base #production-engineering #devops #git #docker #kubernetes #dotnet_