# Contributing

Thank you for your interest in contributing! This project contains infrastructure-as-code and website deployment configurations. Your contributions help improve the system for everyone.

## Overview

This repository contains two main areas:

1. **Infrastructure** (`k8s/`) - Kubernetes deployment, networking, security
2. **Websites** (`sites/`) - Website source files and deployment configs

Contributions to either area are welcome!

## Types of Contributions

### 1. Infrastructure (k8s/)

- **Documentation** - Improving setup guides, security docs, troubleshooting
- **Terraform** - Infrastructure improvements, resource optimization, new features
- **Security** - Hardening, bug fixes, security improvements
- **Operations** - Health checks, monitoring, deployment scripts

### 2. Websites

- **Content** - Updates to website content, fixes, improvements
- **Deployment** - Cloudflare Pages configuration, DNS management
- **Performance** - Optimization, caching, build improvements

## Getting Started

### For Infrastructure Changes

1. Read [docs/infrastructure/README.md](docs/infrastructure/README.md)
2. Understand the architecture ([docs/infrastructure/architecture.md](docs/infrastructure/architecture.md))
3. Review security practices ([docs/infrastructure/security.md](docs/infrastructure/security.md))
4. Follow the setup guide ([docs/infrastructure/setup.md](docs/infrastructure/setup.md))

### For Website Changes

See [docs/websites/README.md](docs/websites/README.md) for website-specific contribution guidelines.

## Development Process

### 1. Fork and Clone

```bash
git clone https://github.com/yourusername/websites-management.git
cd websites-management
```

### 2. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 3. Make Changes

- Keep commits focused and descriptive
- Update documentation for any significant changes
- Test your changes before submitting

### 4. Commit Guidelines

Write clear commit messages:

```
type: brief description

Longer explanation if needed. Reference related issues.

Fixes #123
```

**Types:** feat, fix, docs, security, refactor, test, chore

### 5. Submit Pull Request

- Describe what changed and why
- Reference related issues
- Explain how you tested the changes
- Be open to feedback

## Code Quality Standards

### Terraform Code

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Review changes
terraform plan
```

**Guidelines:**
- Use descriptive resource and variable names
- Add comments for complex logic
- Keep modules focused and reusable
- Document all variables and outputs

### Security Considerations

- **Never commit secrets** (use `terraform.tfvars.example`)
- **Check `.gitignore`** for sensitive files
- **Review security implications** of changes
- **Update [SECURITY.md](docs/infrastructure/security.md)** if security-related

### Documentation

- Keep markdown properly formatted
- Use clear, concise language
- Include code examples where helpful
- Link to related documentation
- Update README if user-facing

## Testing

### Before Submitting

**Infrastructure changes:**
```bash
cd k8s

# 1. Validate syntax
terraform validate
terraform fmt -check -recursive

# 2. Check for secrets
grep -r "AKIA\|private_key\|secret" . --exclude-dir=.terraform

# 3. Plan deployment
terraform plan -out=tfplan
```

**Website changes:**
```bash
# Test build
npm run build  # or equivalent build command

# Verify output
ls -la dist/
```

### Test Coverage

- Verify your changes don't break existing functionality
- Test edge cases and error scenarios
- Check documentation accuracy

## Security Guidelines

### Never Commit

- API keys or tokens
- SSH private keys
- Database credentials
- AWS access keys
- WireGuard private keys
- Any `.tfvars` file with secrets

### Always

- Use `.gitignore` to protect sensitive files
- Document security implications in PRs
- Follow the principle of least privilege
- Report security issues privately

## Code Review Process

All contributions go through review. Reviewers check:

- **Code quality** - clarity, best practices, standards
- **Security** - no secrets, hardening appropriate
- **Tests** - adequate testing, edge cases covered
- **Documentation** - clear, complete, accurate
- **Impact** - does it solve the problem? any side effects?

Be respectful and constructive in feedback!

## Common Pitfalls

1. **Secrets in code** - Always use `terraform.tfvars.example` as template
2. **Incomplete testing** - Test your changes before submitting
3. **Poor commit messages** - Write descriptive messages with context
4. **Missing documentation** - Update docs for user-facing changes
5. **Breaking changes** - Note any breaking changes clearly

## Questions?

- Check [README.md](README.md) for project overview
- Read [docs/README.md](docs/README.md) for documentation index
- Open an issue to discuss before large changes
- Ask in pull request if you need clarification

## License

By contributing, you agree your contributions are licensed under the MIT License (see [LICENSE](LICENSE)).

---

Thank you for helping improve this project! 🚀

