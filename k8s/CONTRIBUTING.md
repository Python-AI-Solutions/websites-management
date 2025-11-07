Contributing
===========

This project uses Pixi to manage developer tools and pre-commit to enforce checks.

- Install Pixi: https://pixi.sh (one-liner: `curl -fsSL https://pixi.sh/install.sh | bash`)
- Install git hooks and tool deps:
  - `pixi run pre-commit-install`
- Run all checks locally:
  - `pixi run pre-commit-run`
  - `pixi run tf-fmt`
  - `pixi run tf-validate`

Notes
-----
- Hooks use system tools from the Pixi environment (tofu, yamllint, shellcheck, shfmt).
- `tofu validate` performs a lightweight `tofu init -backend=false` to avoid touching remote backends; it will download providers as needed.
- CI runs these same tasks via GitHub Actions to prevent regressions.
