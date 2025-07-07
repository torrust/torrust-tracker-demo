# ADR-002: Use Docker for All Services Including UDP Tracker

## Status

Accepted

## Date

2025-01-07

## Context

The Torrust Tracker Demo repository provides a complete deployment environment for
the Torrust Tracker, including the UDP tracker component, HTTP tracker, REST API,
and supporting services (Prometheus, Grafana, MySQL/SQLite).

### Performance Considerations

UDP tracker performance is critical for BitTorrent operations, and several
performance optimization approaches were considered:

1. **Host Network Mode**: Running UDP tracker containers with `--network=host`
   to avoid Docker networking overhead
2. **Connection Tracking Disable**: Disabling `nf_conntrack` to reduce kernel
   overhead for UDP packet processing
3. **Source Compilation**: Running the tracker binary directly on the host
   instead of using Docker containers

### Technical Challenges Identified

During investigation of performance optimizations, several issues were encountered:

1. **Connection Tracking vs Docker**: Docker networking appears to rely on
   connection tracking (`nf_conntrack`) for proper packet routing. Disabling
   connection tracking while using Docker containers resulted in networking
   issues.

2. **Host Mode Limitations**: While host networking mode worked, it created
   complications with service orchestration and port management in the demo
   environment.

3. **Complexity vs Benefit**: Performance optimizations added significant
   complexity to the deployment process and infrastructure management.

### Related Issues

This decision addresses problems documented in previous GitHub issues:

- [torrust/torrust-demo#27](https://github.com/torrust/torrust-demo/issues/27):
  Improve tracker performance by adjusting docker network configuration
- [torrust/torrust-demo#72](https://github.com/torrust/torrust-demo/issues/72):
  Fix nf_conntrack table overflow causing UDP packet drops

## Decision

**Use Docker containers for all services in the Torrust Tracker Demo, including
the UDP tracker, without host networking mode or connection tracking modifications.**

## Rationale

### Primary Goals Alignment

The Torrust Tracker Demo repository has specific primary objectives:

1. **Demo Environment Setup**: Provide a complete, working demonstration of
   Torrust Tracker functionality
2. **Frequent Updates**: Update the demo environment regularly, ideally with
   every tracker release
3. **Declarative Infrastructure**: Maintain Infrastructure as Code approach
   for reproducible deployments
4. **Documentation Generation**: Serve as a reference implementation for
   deployment procedures

### Performance vs Simplicity Trade-off

While Docker networking may introduce some performance overhead compared to
native host networking, the benefits outweigh the costs for this use case:

**Benefits of Docker Approach:**

- **Consistency**: All services use the same orchestration method
- **Simplicity**: Single Docker Compose configuration manages all services
- **Reproducibility**: Identical behavior across different environments
- **Maintenance**: Easier updates and dependency management
- **Documentation**: Clearer examples for users to follow
- **Testing**: Simplified CI/CD and local testing procedures

**Performance Considerations:**

- The demo environment prioritizes functionality demonstration over peak performance
- Users requiring maximum performance can reference this implementation and
  optimize for their specific production needs
- Performance optimizations can be documented separately without complicating
  the base demo

### Future Performance Documentation

Performance optimization will be addressed through:

1. **Dedicated Documentation**: Separate guides for production performance tuning
2. **Configuration Examples**: Performance-focused configuration templates
3. **Best Practices**: Documentation of optimization techniques and trade-offs
4. **Potential Repositories**: Specialized repositories focused on high-performance
   deployments

## Consequences

### Positive Consequences

- **Simplified Deployment**: Single orchestration method for all services
- **Better Documentation**: Clear, consistent examples for users
- **Easier Maintenance**: Streamlined update procedures
- **Improved Testing**: Consistent test environments
- **Faster Development**: Reduced complexity in infrastructure management

### Negative Consequences

- **Performance Overhead**: Some UDP tracker performance impact from Docker networking
- **Resource Usage**: Additional container overhead compared to native binaries
- **Networking Complexity**: Docker networking abstractions may obscure network issues

### Mitigation Strategies

1. **Clear Documentation**: Document the performance trade-offs explicitly
2. **Performance Guidelines**: Provide separate documentation for production
   performance optimization
3. **Configuration Examples**: Include performance-tuned configuration examples
4. **Monitoring**: Include comprehensive monitoring to identify performance issues

### Future Considerations

- Monitor for significant performance issues in demo environment
- Re-evaluate if Docker networking becomes a major limitation
- Consider hybrid approaches for specific production use cases
- Provide migration guides for users who need maximum performance

## Alternatives Considered

### Alternative 1: Host Network Mode

**Description**: Run UDP tracker with `--network=host`

**Pros**:

- Better network performance
- Reduced networking overhead
- Direct access to host network interfaces

**Cons**:

- Port conflicts with host services
- Reduced container isolation
- Complications with service discovery
- More complex firewall configuration

**Decision**: Rejected due to increased complexity and orchestration challenges

### Alternative 2: Native Binary Deployment

**Description**: Compile and run tracker binary directly on host

**Pros**:

- Maximum performance
- No container overhead
- Direct kernel network access

**Cons**:

- Complex dependency management
- Platform-specific build requirements
- Reduced deployment consistency
- More complex update procedures
- Breaking changes to current infrastructure

**Decision**: Rejected due to complexity and maintenance burden

### Alternative 3: Hybrid Approach

**Description**: Use Docker for supporting services, native binary for tracker

**Pros**:

- Performance optimization for critical component
- Maintained orchestration for supporting services

**Cons**:

- Increased complexity
- Mixed deployment methods
- More complex CI/CD pipelines
- Inconsistent documentation examples

**Decision**: Rejected due to increased complexity and mixed approaches

### Alternative 4: Conditional Deployment

**Description**: Support both Docker and native deployment modes

**Pros**:

- User choice for performance vs simplicity
- Flexibility for different use cases

**Cons**:

- Significant maintenance burden
- Complex documentation
- Multiple testing matrices
- Potential for configuration drift

**Decision**: Rejected due to maintenance complexity

## References

- [Torrust Tracker Documentation](https://docs.rs/torrust-tracker/)
- [GitHub Issue #27: Docker Network Configuration](https://github.com/torrust/torrust-demo/issues/27)
- [GitHub Issue #72: nf_conntrack Overflow](https://github.com/torrust/torrust-demo/issues/72)
