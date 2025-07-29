# Environment Configuration

This directory contains the environment configuration system for the Torrust Tracker Demo.

## Files Overview

### Templates and Configuration

- **`base.env.tpl`** - Single base template for all environments (uses variable substitution)
- **`local.defaults`** - Default values for local development environment
- **`production.defaults`** - Default values for production environment template

### Generated Files (Git-Ignored)

- **`local.env`** - Generated local environment configuration (regenerated automatically)
- **`production.env`** - Generated production environment configuration (manual secrets required)

## How It Works

### Twelve-Factor Compliance

This system follows twelve-factor app principles by:

1. **Single Source of Truth**: One base template (`base.env.tpl`) for all environments
2. **Environment-Specific Configuration**: Default files define environment-specific values
3. **Separation of Concerns**: Configuration (defaults) separated from code (scripts)
4. **Version Control**: Default files are tracked, generated files with secrets are ignored

## Template Processing

Templates use environment variable substitution (`envsubst`) to generate final
configuration files:

```bash
# Templates are processed like this:
envsubst < local.env.tpl > local.env
envsubst < production.env.tpl > production.env  # (after manual setup)
```

## Critical Deployment Behavior

### The Git Archive Issue

**IMPORTANT:** When you modify templates in this folder and run E2E tests, the tests
might fail if they depend on the new values. This happens due to how the application
deployment process works:

1. **Infrastructure Provisioning**: New VM is created
2. **Code Deployment**: Git archive is copied to VM (`git archive HEAD`)
3. **Configuration Generation**: Templates are processed on the VM

### The Problem

**`git archive` only includes committed changes, not your working tree changes.**

This means:

- ✅ If you modify templates and **commit** them, E2E tests will use the new values
- ❌ If you modify templates but **don't commit** them, E2E tests will use the old
  committed values

### Example Scenario

```bash
# 1. You modify local.env.tpl to change TRACKER_ADMIN_TOKEN
vim infrastructure/config/environments/local.env.tpl

# 2. You run E2E tests without committing
make test-e2e  # ❌ FAILS - Uses old token from git archive

# 3. You commit your changes
git add infrastructure/config/environments/local.env.tpl
git commit -m "update token"

# 4. You run E2E tests again
make test-e2e  # ✅ PASSES - Uses new token from git archive
```

## Why Git Archive?

The deployment process uses `git archive` for several important reasons:

### Development Benefits

- **Clean Deployment**: Only committed, tested changes are deployed
- **Excludes Local Files**: Doesn't copy `.env` files, build artifacts, or local storage
- **Reproducible**: Same git commit always produces the same deployment
- **Fast**: Compressed archive transfer is faster than full directory sync

### Production Safety

- **Version Control**: Only committed code reaches production
- **No Accidental Deployments**: Prevents deploying uncommitted debug code or secrets
- **Audit Trail**: Clear link between deployments and git commits
- **Rollback Capability**: Easy to redeploy any previous commit

## Best Practices

### For Development (E2E Testing)

1. **Always commit template changes before running E2E tests**:

   ```bash
   git add infrastructure/config/environments/
   git commit -m "update configuration templates"
   make test-e2e
   ```

2. **Check git status before testing**:

   ```bash
   git status  # Should show "working tree clean"
   make test-e2e
   ```

### For Production Deployment

1. **Never modify templates directly in production**
2. **Always test changes in development first**
3. **Use proper git workflow** (feature branches, reviews, etc.)
4. **Verify configuration after deployment**

## Alternative Approaches Considered

### Option 1: Copy Working Tree

```bash
# Instead of: git archive HEAD | tar -xz
rsync -av --exclude='.git' . vm:/path/
```

**Pros**: Includes uncommitted changes

**Cons**:

- Copies local secrets and build artifacts
- No version control guarantee
- Inconsistent between development and production
- Larger transfer size

### Option 2: Separate Config Management

```bash
# Keep templates separate from code deployment
scp infrastructure/config/environments/*.tpl vm:/path/
```

**Pros**: Templates can be updated independently

**Cons**:

- More complex deployment process
- Configuration and code can get out of sync
- Additional deployment step to fail

## Current Choice: Git Archive

We chose to keep `git archive` because:

1. **Production Safety**: Ensures only committed code is deployed
2. **Consistency**: Same process for development and production
3. **Simplicity**: Single deployment artifact
4. **Version Control**: Clear audit trail of what was deployed

The trade-off is that **developers must commit template changes before E2E testing**,
but this is actually a good practice that ensures:

- Template changes are reviewed and tested
- No accidental deployment of uncommitted changes
- Clear history of configuration changes

## Troubleshooting

### E2E Tests Fail After Template Changes

1. **Check if changes are committed**:

   ```bash
   git status infrastructure/config/environments/
   ```

2. **If uncommitted, commit them**:

   ```bash
   git add infrastructure/config/environments/
   git commit -m "update: configuration templates for testing"
   ```

3. **Re-run tests**:

   ```bash
   make test-e2e
   ```

### Configuration Not Updated After Deployment

1. **Verify the git archive contains your changes**:

   ```bash
   git archive HEAD -- infrastructure/config/environments/ | tar -tz
   ```

2. **Check template processing on VM**:

   ```bash
   ssh torrust@$VM_IP 'cd torrust-tracker-demo && cat infrastructure/config/environments/local.env'
   ```

3. **Verify generated configuration**:

   ```bash
   ssh torrust@$VM_IP 'cd torrust-tracker-demo && cat application/.env'
   ```

## Default Files System (New Approach)

### Configuration Architecture

The environment configuration system now uses a single base template with external default files:

- **`base.env.tpl`**: Single template with variable placeholders (`${VARIABLE_NAME}`)
- **`local.defaults`**: Default values for local development
- **`production.defaults`**: Default placeholder values for production

### Benefits

1. **DRY Principle**: Single source of truth for all environment variables
2. **Maintainability**: Add variables once in base template, define values in defaults
3. **Version Control**: Default values are tracked and can be customized
4. **Consistency**: Same template processing logic for all environments

### Usage

```bash
# Generate local environment (uses local.defaults)
./infrastructure/scripts/configure-env.sh local

# Generate production template (uses production.defaults)
./infrastructure/scripts/configure-env.sh production

# Generate secure production secrets
./infrastructure/scripts/configure-env.sh generate-secrets
```

### Customizing Defaults

Edit the `.defaults` files to change environment-specific values:

```bash
# Change local development domain
vim infrastructure/config/environments/local.defaults

# Change production backup retention
vim infrastructure/config/environments/production.defaults
```

The next time you run configuration generation, your changes will be applied.

## Security Notes

- **Never commit production secrets** - Use placeholder values in templates
- **Review template changes** - Configuration changes can affect security
- **Test thoroughly** - Configuration errors can break the entire application
- **Backup production configs** - Before deploying configuration changes

## Related Documentation

- [Deployment Guide](../../../docs/guides/integration-testing-guide.md)
- [Twelve-Factor App Methodology](../../../docs/guides/integration-testing-guide.md#twelve-factor-compliance)
- [Configuration Management ADR](../../../docs/adr/004-configuration-approach-files-vs-environment-variables.md)
