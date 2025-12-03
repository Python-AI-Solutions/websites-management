# Contributing to Kubernetes Infrastructure

Thank you for your interest in contributing to this infrastructure-as-code project!

## Overview

This repository contains production infrastructure for a Kubernetes cluster managed with Terraform and OpenTofu. Contributions help improve the deployment experience, documentation, and overall reliability.

## Types of Contributions

### 1. Documentation Improvements
- Clarifying setup instructions
- Fixing typos or errors
- Adding deployment examples
- Improving security documentation
- Adding troubleshooting guides

### 2. Infrastructure Enhancements
- Adding support for multi-node clusters
- Improving security configurations
- Optimizing resource allocation
- Adding new optional components

### 3. Bug Fixes
- Fixing deployment failures
- Resolving Kubernetes configuration issues
- Addressing terraform plan/apply errors

## Getting Started

### Prerequisites
- OpenTofu ≥ 1.5 (or Terraform ≥ 1.0)
- `kubectl` installed
- AWS credentials configured
- Understanding of Kubernetes and Terraform

### Setting Up Your Development Environment

1. **Fork and clone** the repository:
   ```bash
   git clone https://github.com/yourusername/infrastructure.git
   cd k8s
   ```

2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

3. **Make your changes** and test them

4. **Validate Terraform**:
   ```bash
   terraform fmt -recursive
   terraform validate
   ```

## Making Changes

### For Documentation Changes
- Keep markdown formatting consistent
- Use clear, concise language
- Include code examples where helpful
- Test any shell commands you document

### For Infrastructure Changes
- Test changes in a non-production environment first
- Document what the change does and why
- Update SECURITY.md if security is affected
- Update README.md if user-facing behavior changes
- Include before/after explanations in commits

### For Bug Fixes
- Create an issue describing the bug first (if one doesn't exist)
- Reference the issue in your pull request
- Include steps to reproduce
- Explain the root cause
- Test the fix thoroughly

## Code Quality Standards

### Terraform Code
- Use `terraform fmt` for consistent formatting
- Use descriptive variable and resource names
- Add comments for complex logic
- Keep modules focused and reusable
- Validate with `terraform validate`

### Shell Scripts
- Use `#!/bin/bash` shebang
- Add error handling
- Document usage in comments
- Test on the target OS (Debian)

## Submitting Changes

### Process

1. **Ensure your code is clean**:
   ```bash
   terraform fmt -recursive
   terraform validate
   ```

2. **Create a descriptive commit message**:
   ```
   fix: resolve kubeadm initialization timeout

   - Increase upload-config phase timeout
   - Add retry logic for network-dependent steps
   - Document timeout values in SETUP.md

   Fixes #123
   ```

3. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Open a Pull Request** with:
   - Clear title describing the change
   - Detailed description of what changed and why
   - Any testing you performed
   - References to related issues

### Pull Request Guidelines

- Keep PRs focused on a single concern
- Include documentation updates
- Explain your reasoning for architectural decisions
- Be open to feedback and suggestions
- Update based on code review comments

## Testing Your Changes

### Before Submitting

1. **Validate syntax**:
   ```bash
   terraform validate
   terraform fmt -check -recursive
   ```

2. **Plan the deployment**:
   ```bash
   terraform plan -out=tfplan
   ```

3. **Review the plan** carefully:
   - Check for unexpected resource changes
   - Verify no production resources are affected
   - Ensure security configurations are correct

4. **Document test results** in your PR

## Security Considerations

### Never Commit Secrets
- Ensure `terraform.tfvars` is in `.gitignore`
- Never hardcode credentials in code
- Use the `terraform.tfvars.example` template
- Review commits for accidental secret exposure

### Review Security Changes Carefully
- Changes to SECURITY.md require extra review
- Network configuration changes are sensitive
- Test security controls don't break functionality
- Document security implications in PRs

## Code Review Process

All contributions go through code review. Reviewers will:
- Check code quality and best practices
- Verify security implications
- Test the changes
- Provide constructive feedback

## Questions or Issues?

- Check existing [Issues](../../issues) for similar questions
- Review [SETUP.md](./SETUP.md) and [SECURITY.md](./SECURITY.md) for detailed docs
- Open a new issue to discuss proposed changes

## License

By contributing, you agree that your contributions will be licensed under the same license as this project (see LICENSE file).

## Recognition

Contributors who make significant improvements may be listed in the project's contributors section.

Thank you for helping make this infrastructure better! 🚀
