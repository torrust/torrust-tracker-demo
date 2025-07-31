# ADR-006: SSL Certificate Generation Strategy

## Status

Accepted

## Context

During the implementation of HTTPS support for the Torrust Tracker Demo, we
needed to decide between two approaches for SSL certificate management:

1. **Generate certificates on each deployment** - Create fresh certificates during each deployment process
2. **Reuse certificates across deployments** - Generate certificates once and copy them between deployments

For local testing environments, we consistently use the same domain (`test.local`),
which means certificates could technically be reused. However, for production
environments, different domains are used for different deployment targets.

## Decision

We will **generate SSL certificates on each deployment** rather than reusing
certificates across deployments.

## Rationale

### 1. Production Flexibility

Different environments use different domains:

- Local testing: `test.local`
- Staging environments: `staging.example.com`
- Production: `tracker.torrust-demo.com`

Certificates must match the exact domain being used in each environment.

### 2. Certificate Validity

Self-signed certificates are domain-specific and must exactly match the domain
being used in each deployment environment. Reusing certificates would require
maintaining separate certificate sets for each domain or would fail certificate
validation.

### 3. Security Best Practices

Fresh certificates for each deployment ensure:

- No stale or leaked credentials are reused
- Certificates are generated with current system time
- No cross-environment certificate contamination

### 4. Workflow Consistency

The same deployment process works across all environments without:

- Manual certificate management
- Certificate copying between systems
- Environment-specific deployment procedures
- Certificate store maintenance

### 5. Zero Configuration

This approach requires no additional infrastructure:

- No certificate distribution system
- No certificate storage requirements
- No manual certificate rotation procedures

## Implementation

Certificate generation happens during the application deployment phase (`make app-deploy`):

1. **Self-signed certificates**: Generated using OpenSSL with domain-specific
   Subject Alternative Names (SAN)
2. **Certificate placement**: Stored in `/var/lib/torrust/proxy/certs/` and
   `/var/lib/torrust/proxy/private/` on the target server
3. **Container mounting**: Certificates are mounted into nginx container at runtime
4. **Automatic configuration**: nginx configuration is automatically templated
   with the correct certificate paths

## Consequences

### Positive

- ✅ Identical deployment workflow between local testing and production
- ✅ No certificate management overhead
- ✅ Domain-specific certificates always match deployment target
- ✅ Enhanced security through fresh certificates
- ✅ Simplified deployment automation

### Negative

- ❌ Slight deployment time increase (certificate generation takes ~2-3 seconds)
- ❌ Cannot preserve certificate fingerprints across deployments
- ❌ Requires certificate regeneration for each deployment (even if domain unchanged)

### Neutral

- 🔄 For local testing, certificates are regenerated even though domain remains `test.local`
- 🔄 Certificate validity period is reset on each deployment (10 years for self-signed)

## Alternatives Considered

### Certificate Reuse Strategy

We considered implementing certificate reuse for local testing:

1. Generate certificates once and store them locally
2. Copy stored certificates to VM during deployment
3. Use fresh generation only for production deployments

**Rejected because:**

- Creates environment-specific deployment logic
- Increases complexity for minimal time savings
- Introduces certificate management overhead
- Reduces consistency between local and production workflows

## Related Decisions

- [ADR-004: Configuration Approach Files vs Environment Variables]
  (004-configuration-approach-files-vs-environment-variables.md) -
  Template-based configuration approach
- [ADR-002: Docker for All Services](002-docker-for-all-services.md) -
  Container-based service architecture

## References

- [SSL Certificate Management Documentation](../application/docs/deployment.md#ssl-certificate-management)
- [Deployment Script Implementation](../infrastructure/scripts/deploy-app.sh)
- [Certificate Generation Script](../application/share/bin/ssl-generate-test-certs.sh)
