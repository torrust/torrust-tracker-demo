#!/bin/bash
# Secret generation utility for Torrust Tracker production deployment
# Generates secure random secrets for production environment configuration

set -euo pipefail

echo "=== Torrust Tracker Secret Generator ==="
echo ""
echo "Generating secure random secrets for production deployment..."
echo "Copy these values into your infrastructure/config/environments/production.env file:"
echo ""

echo "# === GENERATED SECRETS ==="
echo "MYSQL_ROOT_PASSWORD=$(gpg --armor --gen-random 1 40)"
echo "MYSQL_PASSWORD=$(gpg --armor --gen-random 1 40)"
echo "TRACKER_ADMIN_TOKEN=$(gpg --armor --gen-random 1 40)"
echo "GF_SECURITY_ADMIN_PASSWORD=$(gpg --armor --gen-random 1 40)"
echo ""

echo "⚠️  Security Notes:"
echo "   - Store these secrets securely"
echo "   - Never commit production.env to version control"
echo "   - Use different secrets for each deployment environment"
echo ""
echo "✅ Next Steps:"
echo "   1. Copy the generated secrets to your production.env file"
echo "   2. Configure DOMAIN_NAME and CERTBOT_EMAIL"
echo "   3. Run: make infra-config-production"
echo ""
