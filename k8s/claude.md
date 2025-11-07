# Claude Development Guidelines

This document outlines the development guidelines and best practices for working with Claude on this project.

## Python Development with uv

For all Python development in this project, use `uv` as the package manager and virtual environment tool. `uv` is a fast Python package installer and resolver written in Rust.

### Initial Setup

1. **Install uv** (if not already installed):
   ```bash
   # macOS/Linux
   curl -LsSf https://astral.sh/uv/install.sh | sh

   # Or using Homebrew
   brew install uv
   ```

2. **Initialize Python project in current directory**:
   ```bash
   uv init
   ```

   This creates:
   - `pyproject.toml` - Project configuration and dependencies
   - `src/` directory - Source code
   - `.python-version` - Python version specification
   - `README.md` - Project documentation (if not exists)

3. **Create and activate virtual environment**:
   ```bash
   # uv automatically creates and manages virtual environments
   # No need to manually create/activate like with pip/venv
   ```

### Package Management

#### Adding Dependencies
```bash
# Add a runtime dependency
uv add requests

# Add a development dependency
uv add --dev pytest

# Add with version constraints
uv add "fastapi>=0.100.0"

# Add from git repository
uv add git+https://github.com/user/repo.git
```

#### Installing Dependencies
```bash
# Install all dependencies from pyproject.toml
uv sync

# Install only production dependencies
uv sync --no-dev
```

#### Running Python Code
```bash
# Run Python scripts (automatically uses project's virtual environment)
uv run python script.py

# Run Python modules
uv run -m pytest

# Run with specific Python version
uv run --python 3.11 python script.py
```

#### Managing Python Versions
```bash
# Install specific Python version
uv python install 3.11

# Use specific Python version for project
uv python pin 3.11

# List available Python versions
uv python list
```

### Project Structure

When using `uv init`, follow this structure:
```
project/
├── pyproject.toml          # Project configuration
├── .python-version         # Python version
├── src/
│   └── your_package/
│       ├── __init__.py
│       └── main.py
├── tests/
│   └── test_main.py
└── README.md
```

### Common Commands

| Task | Command |
|------|---------|
| Initialize project | `uv init` |
| Add dependency | `uv add package-name` |
| Add dev dependency | `uv add --dev package-name` |
| Install dependencies | `uv sync` |
| Run Python script | `uv run python script.py` |
| Run tests | `uv run -m pytest` |
| Update dependencies | `uv lock --upgrade` |
| Remove dependency | `uv remove package-name` |
| Show project info | `uv tree` |

### Integration with GCP and Terraform

For GCP-related Python scripts in this project:

```bash
# Add GCP client libraries
uv add google-cloud-storage google-cloud-container

# Add Terraform/OpenTofu helpers
uv add python-terraform

# Example: Python script to interact with GKE
uv run python scripts/manage_cluster.py
```

### Best Practices

1. **Always use `uv run`** instead of direct `python` commands
2. **Pin Python version** in `.python-version` for consistency
3. **Use `pyproject.toml`** for all project configuration
4. **Separate dev and prod dependencies** using `--dev` flag
5. **Commit `uv.lock`** to ensure reproducible builds
6. **Use `uv sync`** instead of `pip install -r requirements.txt`

### Example pyproject.toml

```toml
[project]
name = "gcp-k8s-admin"
version = "0.1.0"
description = "GCP Kubernetes administration tools"
authors = [
    {name = "Your Name", email = "your.email@example.com"}
]
dependencies = [
    "google-cloud-container>=2.0.0",
    "google-cloud-storage>=2.0.0",
    "pyyaml>=6.0",
]
requires-python = ">=3.11"

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "black>=23.0.0",
    "ruff>=0.1.0",
    "mypy>=1.0.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 88
target-version = "py311"

[tool.black]
line-length = 88
target-version = ['py311']
```

### Migration from pip/venv

If you have an existing `requirements.txt`:

```bash
# Convert requirements.txt to pyproject.toml
uv add -r requirements.txt

# Or import from existing environment
uv pip compile requirements.txt --output-file requirements.lock
uv add $(cat requirements.lock | grep -v '^#' | grep -v '^$')
```

## Development Workflow

1. **Start new Python feature**:
   ```bash
   uv init  # If not already done
   uv add needed-packages
   ```

2. **Write code** in `src/` directory

3. **Run and test**:
   ```bash
   uv run python src/main.py
   uv run -m pytest
   ```

4. **Format and lint**:
   ```bash
   uv run black src/
   uv run ruff check src/
   ```

This approach ensures consistent, fast, and reliable Python development across all project contributors.
