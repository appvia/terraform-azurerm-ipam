# Developer Guide

This guide covers the tooling, automation, and workflows included in this repository.

## Getting Started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [pre-commit](https://pre-commit.com/) — `pip install pre-commit` or `brew install pre-commit`
- [terraform-docs](https://terraform-docs.io/) — `brew install terraform-docs`
- [tflint](https://github.com/terraform-linters/tflint) — `brew install tflint`
- [commitlint](https://commitlint.js.org/) — `brew install commitlint`
- [checkov](https://www.checkov.io/) — `pip install checkov`
- [uv](https://docs.astral.sh/uv/) (optional) — for automatic banner generation on first commit

### Initial Setup

If this repository was created from the [terraform-azurerm-module-template](https://github.com/appvia/terraform-azurerm-module-template):

1. Install pre-commit hooks:

   ```bash
   pre-commit install
   pre-commit install --hook-type commit-msg
   ```

2. Replace the `<NAME>` placeholder in `README.md` with your module name.

3. On your first commit, the `init-from-template` pre-commit hook will automatically:
   - Replace the `__REPO_NAME__` and `__MODULE_NAME__` placeholders in the README banner URLs and registry badge
   - Generate a custom `docs/banner.jpg` with the module name rendered on it (requires [uv](https://docs.astral.sh/uv/))

   The commit will fail with a "files were modified" message. Review the changes, then re-stage and commit again:

   ```bash
   git add README.md docs/banner.jpg
   git commit
   ```

## Pre-commit Hooks

This repository uses [pre-commit](https://pre-commit.com/) for automated code quality checks. Hooks run automatically on every commit.

**Installation:**

```bash
pre-commit install
pre-commit install --hook-type commit-msg
```

**Run all hooks manually:**

```bash
pre-commit run --all-files
```

### Configured Hooks

The following hooks are configured in `.pre-commit-config.yaml`:

| Hook | Source | Purpose |
|------|--------|---------|
| `check-added-large-files` | pre-commit-hooks | Blocks files larger than 500KB |
| `check-case-conflict` | pre-commit-hooks | Detects filename case conflicts |
| `check-json` | pre-commit-hooks | Validates JSON syntax |
| `check-merge-conflict` | pre-commit-hooks | Detects unresolved merge conflict markers |
| `check-symlinks` | pre-commit-hooks | Checks for broken symlinks |
| `check-yaml` | pre-commit-hooks | Validates YAML syntax |
| `end-of-file-fixer` | pre-commit-hooks | Ensures files end with a newline |
| `pretty-format-json` | pre-commit-hooks | Auto-formats JSON with 2-space indent |
| `trailing-whitespace` | pre-commit-hooks | Removes trailing whitespace |
| `check-shebang-scripts-are-executable` | pre-commit-hooks | Ensures scripts with shebangs are executable |
| `check-executables-have-shebangs` | pre-commit-hooks | Ensures executable files have shebangs |
| `no-commit-to-branch` | pre-commit-hooks | Prevents direct commits to `main` |
| `mixed-line-ending` | pre-commit-hooks | Enforces LF line endings |
| `forbid-new-submodules` | pre-commit-hooks | Prevents adding git submodules |
| `gitleaks` | gitleaks | Scans for hardcoded secrets and credentials |
| `actionlint` | actionlint | Lints GitHub Actions workflow files |
| `check-renovate` | check-jsonschema | Validates `renovate.json` against its schema |
| `commitlint` | commitlint | Enforces [Conventional Commits](https://www.conventionalcommits.org/) format |
| `terraform_fmt` | pre-commit-terraform | Auto-formats Terraform files |
| `terraform_validate` | pre-commit-terraform | Validates Terraform configuration |
| `terraform_tflint` | pre-commit-terraform | Lints Terraform with TFLint (azurerm + terraform rulesets) |
| `terraform_checkov` | pre-commit-terraform | Security scanning with Checkov |
| `terraform_docs` | pre-commit-terraform | Auto-generates documentation from Terraform code |
| `shellcheck` | shellcheck-py | Lints shell scripts |
| `init-from-template` | local | Replaces `__REPO_NAME__` / `__MODULE_NAME__` placeholders and generates `docs/banner.jpg` |

### Excluding/Skipping Checks

Prefer inline exclusions where possible so the reason is visible next to the code. Use global config files for patterns that apply across the entire repository.

**Checkov** — inline (preferred):

```hcl
resource "azurerm_storage_account" "example" {
  #checkov:skip=CKV_AZURE_206:Reason for skipping this check
  name = "example"
}
```

Global: add check IDs to the `skip-check` list in `.checkov.yml`.

**TFLint** — inline (preferred):

```hcl
# tflint-ignore: terraform_unused_declarations
variable "unused_but_required" {
```

Global: set `enabled = false` on the rule in `.tflint.hcl`.

**Gitleaks** — inline (preferred):

```bash
export API_KEY="not-a-real-secret" # gitleaks:allow
```

Global: add patterns to the `[allowlist]` section in `.gitleaks.toml`.

**Shellcheck** — inline (preferred):

```bash
# shellcheck disable=SC2086
echo $unquoted_variable
```

Global: add directives to `.shellcheckrc`.

**Pre-commit hooks** — per-hook file exclusions in `.pre-commit-config.yaml`:

```yaml
- id: check-json
  exclude: |
    (?x)^(
        path/to/excluded/file.json
    )$
```

One-off skip (not recommended for regular use): `SKIP=hook_id git commit -m "message"`

## Dependency Management

Two dependency update tools are configured - Dependabot is simpler and native to GitHub, but renovate allows more flexibility and wider range of dependency management capabilities:

### Dependabot

Configuration: `.github/dependabot.yml`

- Updates GitHub Actions and Terraform dependencies weekly (Mondays)
- Scans `/`, `/examples/*`, and `/modules/*` directories
- Groups updates by ecosystem to reduce PR noise
- Commit messages use Conventional Commits format (`chore(scope): ...`)

### Renovate

Configuration: `renovate.json`

- Updates pre-commit hooks, TFLint plugins, GitHub Actions, Terraform providers, and Terraform modules
- Groups related updates into single PRs
- Runs on early Monday schedule

## Updating Documentation

Terraform input/output/provider documentation is auto-generated using [terraform-docs](https://terraform-docs.io/).

- Configuration: `.terraform-docs.yml`
- Documentation is injected between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` markers in README files
- Regenerate manually: `make documentation` or `terraform-docs .`
- The `terraform_docs` pre-commit hook regenerates docs automatically on each commit - you do not need to do this manually.

## CI/CD Workflows

### Terraform Validation

Configuration: `.github/workflows/terraform.yml`

- Triggers on push to `main` and pull requests targeting `main`
- Uses the shared `appvia/appvia-cicd-workflows` reusable workflow for module validation
- Includes concurrency control (cancels in-progress runs on new pushes)

### Release

Configuration: `.github/workflows/release.yml`

Releases are **not** triggered by merging to `main`. Once your PR is merged, you must create and push a version tag to trigger the release pipeline:

```bash
git checkout main && git pull
git tag v1.0.0
git push origin v1.0.0
```

The workflow uses the shared [`appvia/appvia-cicd-workflows`](https://github.com/appvia/appvia-cicd-workflows) reusable workflow, which:

1. Checks out the full repository history.
2. Identifies the previous version tag.
3. Creates a GitHub Release titled `Release <tag>` with auto-generated release notes covering all changes since the last tag.

Tags must follow [semantic versioning](https://semver.org/) prefixed with `v` (e.g. `v1.0.0`, `v0.2.1`).

#### Customising Release Notes with git-cliff

By default the workflow uses GitHub's built-in release notes (based on PR titles and labels). For more control, you can enable [git-cliff](https://git-cliff.org/):

1. Pass `enable-cliff: true` to the reusable workflow in `.github/workflows/release.yml`:

   ```yaml
   jobs:
     release:
       uses: appvia/appvia-cicd-workflows/.github/workflows/terraform-module-release.yml@v0.0.11
       name: GitHub Release
       with:
         enable-cliff: true
   ```

2. Create a `.cliff/cliff.toml` configuration file in the repository root. This controls how commits are parsed, grouped, and rendered in the changelog. See the [git-cliff documentation](https://git-cliff.org/docs/configuration) for the full reference. A minimal example:

   ```toml
   [changelog]
   header = ""
   body = """
   {% for group, commits in commits | group_by(attribute="group") %}
   ### {{ group | upper_first }}
   {% for commit in commits %}
   - {{ commit.message | upper_first }} ({{ commit.id | truncate(length=7, end="") }})
   {% endfor %}
   {% endfor %}
   """
   trim = true

   [git]
   conventional_commits = true
   commit_parsers = [
     { message = "^feat", group = "Features" },
     { message = "^fix", group = "Bug Fixes" },
     { message = "^docs", group = "Documentation" },
     { message = "^chore", group = "Miscellaneous" },
     { message = "^refactor", group = "Refactor" },
   ]
   ```

When enabled, git-cliff generates the changelog from commits between the previous tag and HEAD, and attaches it to the GitHub Release instead of the default notes.

## Makefile Targets

Run `make <target>` for common development tasks:

| Target | Description |
|--------|-------------|
| `make all` | Run init, validate, tests, lint, security, format, and documentation |
| `make init` | Run `terraform init` across all directories |
| `make validate` | Run `terraform validate` across root, modules, and examples |
| `make tests` | Run `terraform test` |
| `make lint` | Run TFLint across root, modules, and examples |
| `make security` | Run Checkov security scanning |
| `make format` | Run `terraform fmt` recursively |
| `make documentation` | Generate terraform-docs for all directories |
| `make clean` | Remove all `.terraform` directories |
