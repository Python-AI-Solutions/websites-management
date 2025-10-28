Absolutely—managing your DNS (and later the registrar bits) in a repo with OpenTofu is a great move. Below is a ready-to-paste Codex prompt that will scaffold a repo to manage pythonaisolutions.com and any subdomains via Cloudflare, using IaC, workspaces (staging/prod), modules, pre-commit, and a Dockerized OpenTofu toolchain orchestrated by Pixi tasks (so you avoid pip/conda on your host).
You are to generate a complete Git repository that manages Cloudflare DNS for the root zone pythonaisolutions.com and subdomains using OpenTofu (Terraform-compatible), with a clean module structure, workspaces, and CI. The user will handle registrar transfer steps manually later; this repo is strictly for DNS/state/automation.

Goals
	•	Infrastructure as Code for Cloudflare DNS (root + multiple subdomains).
	•	Use OpenTofu via a container; orchestrate with Pixi tasks (no pip/conda on host).
	•	Keep secrets out of the repo; support local .env and GitHub Actions secrets.
	•	Provide Gmail/Google Workspace DNS helpers (MX/SPF/DMARC/DKIM placeholders).
	•	Support staging and prod via workspaces and *.tfvars.
	•	Pre-commit checks, linting, plans on PR, guarded applies on main.

Constraints & Conventions
	•	Do not commit state. Use local state by default (user may later switch to S3/R2 backend).
	•	Provider: cloudflare (API token via env).
	•	DNSSEC is managed in Cloudflare UI; here we only do zone records.
	•	Reusable modules for zones and records.
	•	Keep everything copy-paste runnable.
	•	Avoid vendor lock-in: plain OpenTofu + Cloudflare provider, optional backend placeholders commented.

Repository Structure

cloudflare-dns/
  README.md
  .gitignore
  .env.example
  pixi.toml
  pre-commit-config.yaml
  .github/
    workflows/
      ci.yml
  docker/
    tofu.Dockerfile
  scripts/
    tofu.sh
    load-env.sh
  envs/
    staging.tfvars
    prod.tfvars
  root/
    main.tf
    providers.tf
    versions.tf
    variables.tf
    outputs.tf
  modules/
    cloudflare-zone/
      main.tf
      variables.tf
      outputs.tf
    cloudflare-records/
      main.tf
      variables.tf
      outputs.tf
    google-workspace-email/
      main.tf
      variables.tf
      outputs.tf

What each piece should do

1) pixi.toml
	•	Define tasks:
	•	fmt → run tofu fmt (check + write)
	•	validate → tofu validate
	•	init → scripts/tofu.sh init
	•	ws:staging / ws:prod → select/create workspace
	•	plan:staging / plan:prod → plan with envs/*.tfvars
	•	apply:staging / apply:prod → apply with -auto-approve (user can remove flag)
	•	pre-commit:install / pre-commit:run
	•	Pixi is only for task runner + pre-commit; OpenTofu itself runs in Docker.

2) Containerized OpenTofu
	•	docker/tofu.Dockerfile with:
	•	base: ghcr.io/opentofu/opentofu:latest
	•	add tflint (download static binary) and bash/curl
	•	scripts/tofu.sh runs the container with mounted repo and forwards args:
	•	mounts current dir
	•	passes env vars: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, TF_VAR_zone_name, etc.
	•	default working dir: root/
	•	scripts/load-env.sh to source .env if present.

3) Provider & versions
	•	root/providers.tf:
	•	cloudflare provider, version pinned to a recent stable (e.g. ~> 4.30)
	•	provider auth via CLOUDFLARE_API_TOKEN env only
	•	root/versions.tf:
	•	required_version = ">= 1.7.0" (OpenTofu)
	•	required providers block
	•	Commented backend block showing how to switch to S3/R2 + DynamoDB later.

4) Modules
	•	modules/cloudflare-zone: create/lookup the zone; output zone id, name.
	•	modules/cloudflare-records: create lists of A/AAAA/CNAME/TXT/MX/CAA records from input objects (map/list).
	•	modules/google-workspace-email:
	•	Creates MX for Gmail:
	•	1 ASPMX.L.GOOGLE.COM. (priority 1)
	•	5 ALT1.ASPMX.L.GOOGLE.COM.
	•	5 ALT2.ASPMX.L.GOOGLE.COM.
	•	10 ALT3.ASPMX.L.GOOGLE.COM.
	•	10 ALT4.ASPMX.L.GOOGLE.COM.
	•	SPF TXT: v=spf1 include:_spf.google.com ~all (allow override)
	•	DMARC TXT on _dmarc: configurable policy (none|quarantine|reject), rua, ruf, pct
	•	DKIM placeholders: accepts a list of DKIM selectors and values (user will paste live Google values later). Don’t hardcode the selector; parametrize.

5) Root composition (root/main.tf)
	•	Inputs:
	•	zone_name = "pythonaisolutions.com"
	•	gmail_enabled = true
	•	Optionally records for root and subdomains (e.g., app, www, mx, autodiscover if ever needed, etc.)
	•	Instantiate modules:
	•	cloudflare-zone to fetch zone
	•	google-workspace-email when gmail_enabled
	•	cloudflare-records for:
	•	root apex records (A/AAAA/CNAME/TXT/CAA)
	•	subdomain groups (e.g., app.pythonaisolutions.com, mlflow.pythonaisolutions.com, etc.)
	•	Use for_each maps to define many records cleanly.

6) Workspaces & tfvars
	•	envs/staging.tfvars and envs/prod.tfvars
	•	Same zone_name, but possibly different record sets (e.g., staging points to staging IPs).
	•	README documents workspace commands.

7) Pre-commit
	•	Hooks: end-of-file-fixer, trailing-whitespace, tofu_fmt, tflint
	•	Add .tflint.hcl if needed, with Cloudflare rules enabled.

8) GitHub Actions (.github/workflows/ci.yml)
	•	On PR: init, select workspace from label or default staging, plan and upload plan artifact.
	•	On push to main: require environment approval named prod, then apply prod.
	•	Use CLOUDFLARE_API_TOKEN from GitHub Secrets. Do not echo secrets.

9) README.md
	•	Explain:
	•	Prereqs: Docker, Pixi
	•	.env variables
	•	Commands to init, select workspace, plan/apply
	•	How to paste DKIM TXT values once Google provides them
	•	How to add a new subdomain using the records module
	•	How to switch to a remote backend later (S3/R2 + DynamoDB for locks)
	•	Provide Gmail DNS checklist so email never breaks:
	•	MX, SPF, DKIM, DMARC, and optional Google site verification TXT.

10) .env.example
	•	Include:
	•	CLOUDFLARE_API_TOKEN=
	•	CLOUDFLARE_ACCOUNT_ID=
	•	TF_VAR_zone_name=pythonaisolutions.com
	•	Optional DMARC addresses, SPF policy, etc.

Example Inputs (root/variables.tf)
	•	zone_name (string)
	•	gmail_enabled (bool, default true)
	•	dmarc_policy (string, default “quarantine”)
	•	dmarc_rua (string, default “mailto:dmarc@pythonaisolutions.com”)
	•	spf_txt (string, default v=spf1 include:_spf.google.com ~all)
	•	dkim_records (map of objects: { selector = string, name = string, value = string }[])
	•	apex_records (object with lists for A/AAAA/CNAME/TXT/CAA)
	•	subdomain_records (map(string ⇒ same record object as apex))

Minimal Record Examples (for envs/prod.tfvars)
	•	Root:
	•	A → none (using proxy via CNAME to @ -> e.g., your hosting)
	•	CNAME → www → pythonaisolutions.com
	•	TXT: google-site-verification (placeholder)
	•	Subdomain:
	•	mlflow → CNAME to your current hostname (placeholder)
	•	app → A → your IP (placeholder)
	•	Gmail:
	•	MX + SPF enabled
	•	DMARC: p=quarantine; rua=mailto:dmarc@pythonaisolutions.com; pct=100
	•	DKIM: leave list empty until Google provides values.

Deliverables
	1.	All files listed above with working, linted HCL.
	2.	Sensible defaults, placeholders clearly marked # TODO.
	3.	Commands in README that work end-to-end:
	•	pixi run init
	•	pixi run ws:staging
	•	pixi run plan:staging
	•	pixi run apply:staging
	•	(Same for prod)

Generate the entire repo content accordingly.
