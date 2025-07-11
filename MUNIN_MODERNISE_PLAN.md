# Munin Swift 6 Modernization Plan

## Overview

This document outlines the comprehensive plan to modernize the Munin static gallery generator from Swift 5.8 to Swift 6, ensuring it builds and runs properly on Linux with modern Swift practices.

## Current State Analysis

### Project Structure
- **Main executable**: `Sources/Munin/main.swift` - CLI entry point using ArgumentParser
- **Core library**: `Sources/MuninKit/` - Gallery generation logic
- **Test suites**: `Tests/MuninTests/` and `Tests/MuninKitTests/`
- **Dependencies**: Uses C libraries (libgd, libiptcdata, libexif) and Swift packages
- **Build system**: Swift Package Manager with Makefile wrappers
- **Current Swift**: 5.8 (needs upgrade to 6.x)

### Key Dependencies Analysis
- **swift-vips**: Image processing (uses main branch, potential stability issues)
- **SwiftExif**: EXIF metadata extraction (custom fork at 0.0.7)
- **swift-log**: Logging framework (1.5.4, needs update)
- **Configuration**: IBM Kitura Configuration (3.1.0, deprecated)
- **Rainbow**: Terminal colors (4.0.1)
- **swift-tools-support-core**: Utility functions (0.6.1, deprecated)
- **swift-argument-parser**: CLI parsing (1.4.0, needs update)

### Technical Debt Identified
1. **Swift version**: Currently 5.8, needs 6.x upgrade
2. **Deprecated dependencies**: Configuration, swift-tools-support-core
3. **Concurrency**: Uses GCD instead of modern async/await
4. **Progress animations**: Custom implementation, could use modern alternatives
5. **Code generation**: Uses Sourcery for protocols
6. **Linux compatibility**: Limited platform-specific code

## Modernization Goals

### Primary Objectives
- [x] ✅ **Analysis Complete**: Understand current codebase structure
- [ ] 🔄 **Swift 6 Upgrade**: Migrate to Swift 6.x with strict concurrency
- [ ] 🔄 **Dependency Modernization**: Replace deprecated dependencies
- [ ] 🔄 **Concurrency Modernization**: Adopt async/await and actors
- [ ] 🔄 **Linux Compatibility**: Ensure full Linux build/run support
- [ ] 🔄 **Code Quality**: Apply modern Swift idioms and best practices
- [ ] 🔄 **Testing**: Ensure all tests pass on Linux
- [ ] 🔄 **Performance**: Maintain or improve performance

### Stretch Goals
- [ ] **Static Binary**: Enable static Swift binary compilation
- [ ] **Documentation**: Improve code documentation
- [ ] **CI/CD**: Add Linux-specific CI workflows

## Development Methodology

### Approach
1. **Compile Often**: Run `swift build` after every significant change
2. **Test Often**: Run `swift test` to ensure functionality remains intact
3. **Commit Often**: Make small, focused commits with clear messages
4. **Never Push**: Keep all changes local until review

### Tools Required
- [ ] **System Dependencies**: libgd-dev, libiptcdata-dev, libexif-dev
- [ ] **Swift 6.x**: Latest stable Swift toolchain
- [ ] **Development Tools**: swiftlint, swift-format (if available)

## Detailed Implementation Plan

### Phase 1: Environment Setup
- [ ] **Install System Dependencies**
  - [ ] Install libgd-dev for image processing
  - [ ] Install libiptcdata-dev for IPTC metadata
  - [ ] Install libexif-dev for EXIF data
  - [ ] Verify all C libraries are properly linked
- [ ] **Swift Environment**
  - [ ] Update .swift-version to Swift 6.x
  - [ ] Test basic Swift 6 compilation
  - [ ] Verify Package.swift compatibility

### Phase 2: Dependency Modernization
- [ ] **Update Package.swift**
  - [ ] Upgrade swift-tools-version to 6.0
  - [ ] Update swift-log to latest (1.6.x)
  - [ ] Update swift-argument-parser to latest (1.5.x)
  - [ ] Replace Configuration with modern alternative
  - [ ] Replace swift-tools-support-core functionality
  - [ ] Pin swift-vips to stable release instead of main branch
  - [ ] Update Rainbow to latest version
- [ ] **Resolve Dependency Conflicts**
  - [ ] Test all dependencies build on Linux
  - [ ] Fix any version conflicts
  - [ ] Verify C library linking works

### Phase 3: Swift 6 Language Migration
- [ ] **Enable Swift 6 Language Mode**
  - [ ] Update Package.swift for Swift 6
  - [ ] Enable strict concurrency checking
  - [ ] Fix compilation errors
- [ ] **Sendable Conformance**
  - [ ] Make data structures Sendable where appropriate
  - [ ] Fix non-Sendable type usage across concurrency boundaries
  - [ ] Update Photo, Album, Gallery types
- [ ] **Actor Migration**
  - [ ] Convert State class to actor if needed
  - [ ] Protect shared mutable state with actors
  - [ ] Update queue-based synchronization

### Phase 4: Concurrency Modernization
- [ ] **Replace GCD with Async/Await**
  - [ ] Convert photoQueue operations to async functions
  - [ ] Replace DispatchGroup with TaskGroup
  - [ ] Modernize progress tracking
- [ ] **Structured Concurrency**
  - [ ] Use TaskGroup for parallel image processing
  - [ ] Implement proper cancellation support
  - [ ] Add async context propagation
- [ ] **Performance Validation**
  - [ ] Benchmark new async implementation
  - [ ] Ensure no performance regression
  - [ ] Test memory usage patterns

### Phase 5: Code Quality Improvements
- [ ] **Modern Swift Idioms**
  - [ ] Use computed properties where appropriate
  - [ ] Apply property wrappers for configuration
  - [ ] Improve error handling with Result types
- [ ] **Type Safety**
  - [ ] Add more specific types instead of String/Any
  - [ ] Improve optionals handling
  - [ ] Use enum cases for constants
- [ ] **Code Organization**
  - [ ] Split large files into focused modules
  - [ ] Improve separation of concerns
  - [ ] Add proper access control

### Phase 6: Configuration System Replacement
- [ ] **Replace IBM Configuration**
  - [ ] Implement custom configuration using Codable
  - [ ] Support JSON configuration files
  - [ ] Add environment variable support
  - [ ] Maintain backward compatibility with munin.json
- [ ] **Configuration Validation**
  - [ ] Add configuration schema validation
  - [ ] Provide helpful error messages
  - [ ] Support configuration migration

### Phase 7: Linux Compatibility
- [ ] **Build System**
  - [ ] Test swift build on Linux
  - [ ] Verify Makefile targets work
  - [ ] Fix any Linux-specific issues
- [ ] **C Library Integration**
  - [ ] Test all C library bindings on Linux
  - [ ] Verify VIPS integration works
  - [ ] Check metadata extraction functions
- [ ] **File System Operations**
  - [ ] Test Unicode filename handling
  - [ ] Verify path operations work correctly
  - [ ] Check permission handling

### Phase 8: Testing and Validation
- [ ] **Unit Tests**
  - [ ] Update all tests for new APIs
  - [ ] Add tests for new async functionality
  - [ ] Verify tests pass on Linux
- [ ] **Integration Tests**
  - [ ] Test with example gallery
  - [ ] Verify JSON output compatibility
  - [ ] Test image processing pipeline
- [ ] **Performance Tests**
  - [ ] Benchmark against original version
  - [ ] Test memory usage
  - [ ] Verify concurrent processing efficiency

### Phase 9: Static Binary Support (Stretch)
- [ ] **Static Linking Research**
  - [ ] Investigate Swift static binary requirements
  - [ ] Test C library static linking
  - [ ] Resolve any compatibility issues
- [ ] **Build Configuration**
  - [ ] Add static build flags
  - [ ] Update Package.swift for static builds
  - [ ] Test static binary functionality
- [ ] **Distribution**
  - [ ] Create static binary build scripts
  - [ ] Test deployment scenarios
  - [ ] Document static build process

## Risk Assessment

### High Risk Items
1. **C Library Compatibility**: VIPS and metadata libraries may have issues with Swift 6
2. **Performance Regression**: Async/await conversion might impact performance
3. **API Breaking Changes**: Swift 6 strict concurrency may require significant changes

### Mitigation Strategies
1. **Incremental Migration**: Test each phase thoroughly before proceeding
2. **Performance Monitoring**: Benchmark critical paths continuously
3. **Rollback Plan**: Keep working version available for comparison

## Success Criteria

### Must Have
- [ ] ✅ **Builds Successfully**: Clean build with Swift 6 on Linux
- [ ] ✅ **Tests Pass**: All unit and integration tests pass
- [ ] ✅ **Functional Compatibility**: Generates same JSON output format
- [ ] ✅ **Performance**: No significant performance regression

### Nice to Have
- [ ] **Static Binary**: Successfully builds static executable
- [ ] **Improved Performance**: Better than original with async/await
- [ ] **Better Error Handling**: More descriptive error messages
- [ ] **Code Quality**: Cleaner, more maintainable codebase

## Progress Tracking

This plan will be updated as work progresses. Each checkbox represents a completed task, and commits will reference specific plan items.

**Current Status**: Phase 1 - Environment Setup
**Next Milestone**: Complete dependency analysis and system setup
**Estimated Timeline**: 2-3 weeks for full modernization

---

**Last Updated**: 2025-07-11
**Swift Version Target**: 6.1.2
**Platform Target**: Ubuntu Linux