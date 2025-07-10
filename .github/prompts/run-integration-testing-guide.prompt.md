---
mode: agent
---

# Integration Testing Guide Execution Instructions

As an expert system administrator, you will execute the **complete integration testing process** following the [Integration Testing Guide](../../docs/guides/integration-testing-guide.md).

## 📋 Overview

This guide performs a **full end-to-end integration test** that includes:

1. **Clean existing state** (VM, application data, certificates)
2. **Deploy fresh infrastructure** (VM with Ubuntu 24.04)
3. **Wait for cloud-init completion** (system provisioning)
4. **Run comprehensive integration tests** (services, connectivity, functionality)
5. **Perform smoke testing** (external validation with official client tools)
6. **Clean up resources** (return to clean state)

**Expected Duration**: ~8-12 minutes total
**Prerequisites**: Must have completed initial setup (`make test-prereq`)

## 🎯 Execution Requirements

### CRITICAL Rules to Follow:

1. **Sequential Execution**: Follow steps in exact order - do NOT skip or reorder
2. **No Command Modifications**: Execute commands exactly as written in the guide
3. **Working Directory**: Always run from project root directory
4. **Error Handling**: Document any failures or deviations immediately
5. **Complete Process**: Execute the entire guide from start to finish

### What Gets Cleaned (Destructive Operations):

- **Virtual Machine**: Complete VM destruction and recreation
- **Application Storage**: Database, SSL certificates, configuration files
- **OpenTofu State**: Infrastructure state reset
- **libvirt Resources**: VM disks, cloud-init ISOs, network configurations

## 📝 Step-by-Step Instructions

### Phase 1: Preparation and Cleanup

- **Step 1.1-1.8**: Clean existing infrastructure and application state
- **Critical**: Step 1.8 (Clean Application Storage) is destructive but recommended
- **Outcome**: Clean slate for fresh deployment

### Phase 2: Infrastructure Deployment

- **Step 2.1-2.4**: Deploy VM with OpenTofu/Terraform
- **Critical**: Wait for cloud-init completion (Step 3)
- **Outcome**: Provisioned VM with Torrust Tracker ready

### Phase 3: Integration Testing

- **Step 4**: Run comprehensive integration tests
- **Step 5**: Optional manual verification
- **Step 6**: Optional performance testing
- **Outcome**: Validated working system

### Phase 4: External Validation

- **Step 7**: External smoke testing with official client tools
- **Reference**: Use [Smoke Testing Guide](../../docs/guides/smoke-testing-guide.md) for details
- **Outcome**: Black-box validation of tracker functionality

### Phase 5: Cleanup

- **Step 8**: Clean up all resources
- **Step 9**: Review insights and best practices
- **Outcome**: Return to clean state

## 🚨 Important Notes

### SSH Key Configuration

- **Required**: Must configure SSH keys before deployment
- **Location**: `infrastructure/terraform/local.tfvars`
- **Template**: Available in `infrastructure/terraform/terraform.tfvars.example`

### Cloud-Init Wait Time

- **Critical**: DO NOT skip Step 3 (cloud-init completion)
- **Duration**: 2-3 minutes typically
- **Failure Mode**: SSH connection failures if rushed

### Error Documentation

- **Immediate**: Document any command failures or unexpected outputs
- **Location**: Add issues directly to the integration testing guide
- **Format**: Include error messages, context, and resolution steps

### Non-Standard Commands

- **Approval Required**: Only execute commands not in the guide if absolutely necessary
- **Documentation**: Clearly indicate when deviating from guide
- **Justification**: Explain why the deviation was needed

## 🔧 Troubleshooting Guidance

### Common Issues and Solutions:

1. **"Command not found"**: Verify you're in project root directory
2. **SSH connection failures**: Ensure cloud-init has completed
3. **libvirt permission errors**: Check user is in libvirt group
4. **VM deployment timeouts**: Normal during cloud-init, wait longer
5. **Storage volume conflicts**: Run manual cleanup steps from guide

### When to Deviate from Guide:

- **System-specific issues**: Different Linux distributions may need adjustments
- **Network configuration**: Firewall or DNS issues requiring resolution
- **Permission problems**: User/group configuration fixes
- **Always document**: Any deviations with full explanation

## 📊 Success Criteria

### Integration Test Success Indicators:

- ✅ All services start successfully (Docker Compose)
- ✅ Tracker responds to UDP/HTTP requests
- ✅ API endpoints return expected data
- ✅ Grafana dashboards display metrics
- ✅ MySQL database is accessible and functional

### Smoke Test Success Indicators:

- ✅ UDP tracker clients receive responses
- ✅ HTTP tracker clients receive responses
- ✅ API health checks return "Ok"
- ✅ Statistics endpoints return valid data
- ✅ Metrics endpoints return Prometheus data

## 🎯 Final Deliverables

Upon completion, you should have:

1. **Executed Complete Guide**: All steps from 1.1 through 9
2. **Documented Issues**: Any problems encountered and how they were resolved
3. **Validated Functionality**: Both integration and smoke tests passed
4. **Clean State**: All resources cleaned up and ready for next test
5. **Updated Documentation**: Any guide improvements or corrections needed

## 📖 Additional Resources

- **Integration Testing Guide**: [docs/guides/integration-testing-guide.md](../../docs/guides/integration-testing-guide.md)
- **Smoke Testing Guide**: [docs/guides/smoke-testing-guide.md](../../docs/guides/smoke-testing-guide.md)
- **Quick Start Guide**: [docs/infrastructure/quick-start.md](../../docs/infrastructure/quick-start.md)
- **Troubleshooting**: See infrastructure documentation for libvirt and OpenTofu issues

---

**Remember**: This is a comprehensive test that validates the entire deployment pipeline. Take your time, follow each step carefully, and document everything for future improvements.
