# Recharged Model Comparison App

`tesla-used-evaluator` evolved into a generic model comparison app that used `recharged.com` as an external scraped data source. Do not treat `recharged.com` as a domain managed by this repository.

## Current Status

- No remote repository URL for the app is recorded in this parent repo.
- No `.gitmodules` entry or `sites/recharged-model-comparison` gitlink has been added.
- No DNS or Cloudflare Pages inventory should be added for `recharged.com`; it is external.
- The app previously depended on Supabase, and that database may now be frozen.
- Backend migration to the future Kubernetes deployment is deferred.

## Deferred Parent-Repo Action

If this app is revived, create or identify the distinct app repository first, then add it as a submodule from a clean parent-repo checkout:

```bash
git submodule add <APP_REPO_URL> sites/recharged-model-comparison
```

That command should create parent metadata with the real URL substituted:

```gitconfig
[submodule "sites/recharged-model-comparison"]
	path = sites/recharged-model-comparison
	url = <APP_REPO_URL>
```

Update `sites/README.md` and `envs/prod.tfvars` only after the app repository, frontend deployment target, and replacement backend plan are known.
