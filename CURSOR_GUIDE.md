# Cursor AI Development Guide

This guide helps you work with this RF Automation Infrastructure project using Cursor AI alongside Claude Code.

## Project Context for Cursor

### What is This Project?

An enterprise on-premise RF equipment test automation system featuring:
- **Robot Framework** tests for RF equipment (Spectrum Analyzers, Signal Generators)
- **Docker** containerization for consistent test execution
- **Jenkins** CI/CD pipeline for automated testing
- **ELK Stack** (Elasticsearch + Kibana) for results storage and visualization
- **Python 3.11** for scripting and automation
- **Ubuntu Server 24.04** on Intel NUC hardware

### Project Architecture

```
Intel NUC Server
├── Jenkins (Orchestration)
├── Docker Engine
│   ├── RF Test Runner Container (Robot Framework + Python)
│   ├── Elasticsearch Container (Test Results DB)
│   └── Kibana Container (Dashboards)
└── Network
    ├── Office Network (Git, Updates)
    └── Lab VLAN 192.168.50.x (RF Equipment)
```

## File Organization

### Core Files (Read These First)

1. **README.md** - Project overview and quick start
2. **PROJECT_SUMMARY.md** - Quick reference guide
3. **docs/ARCHITECTURE.md** - System design details
4. **docs/DEVELOPMENT.md** - How to write tests
5. **Makefile** - Common commands

### Code Files

| File | Purpose | Language |
|------|---------|----------|
| `tests/*.robot` | Test cases | Robot Framework |
| `resources/rf_keywords.resource` | Reusable keywords | Robot Framework |
| `resources/network_vars.py` | Equipment configuration | Python |
| `scripts/upload_to_elastic.py` | Results uploader | Python |
| `Dockerfile` | Test container definition | Docker |
| `Jenkinsfile` | CI/CD pipeline | Groovy |
| `infra/docker-compose.yml` | ELK Stack definition | YAML |

## Common Development Tasks with Cursor

### 1. Adding a New Test

**Prompt for Cursor**:
```
Add a new Robot Framework test case to tests/rf_functional.robot that:
- Verifies signal generator frequency stability over time
- Measures frequency at 1 GHz for 60 seconds
- Checks frequency drift is less than 100 Hz
- Uses existing keywords from resources/rf_keywords.resource
- Follows the project's test case naming convention (TC###)
- Includes proper documentation and tags
```

### 2. Adding New Equipment Support

**Prompt for Cursor**:
```
Add support for a new RF equipment "PowerMeter" at IP 192.168.50.14:
1. Update resources/network_vars.py EQUIPMENT_LIST
2. Create connection keyword in resources/rf_keywords.resource
3. Add power measurement keywords (Connect, Configure, Measure)
4. Create a basic test in tests/power_meter.robot
5. Follow the existing code style and patterns
```

### 3. Debugging Test Failures

**Prompt for Cursor**:
```
Help me debug this Robot Framework test failure:
[Paste error message here]

Context:
- Test file: tests/rf_functional.robot
- Failing test: TC005: Measure Signal Power
- Equipment: Spectrum Analyzer at 192.168.50.10
- Error type: [Connection timeout / Assertion failure / etc.]

Please suggest fixes following the project's error handling patterns.
```

### 4. Improving Python Scripts

**Prompt for Cursor**:
```
Improve scripts/upload_to_elastic.py to:
- Add better error handling for Elasticsearch connection failures
- Include retry logic (3 attempts with exponential backoff)
- Add more detailed logging
- Maintain compatibility with existing code
- Follow the project's Python style (type hints, docstrings)
```

### 5. Infrastructure Changes

**Prompt for Cursor**:
```
Modify infra/docker-compose.yml to:
- Increase Elasticsearch heap from 2GB to 4GB
- Add resource limits (CPU: 2 cores, Memory: 6GB)
- Add health checks with proper timeout values
- Maintain compatibility with existing setup
```

## Project-Specific Guidelines for Cursor

### Robot Framework Style

When writing .robot files:
- Use 4-space indentation
- Test case names: `TC###: Descriptive Name`
- Always add `[Documentation]` and `[Tags]`
- Include units in comments: `${FREQUENCY} 1000000000 # 1 GHz`
- Use meaningful variable names: `${POWER_TOLERANCE}` not `${TOL}`

### Python Style

When writing .py files:
- Follow PEP 8
- Use type hints: `def measure_power(freq: int) -> float:`
- Add docstrings with Google style
- Include error handling
- Use loguru for logging

### Keywords Organization

In `resources/rf_keywords.resource`:
- Group keywords by category (Connection, Configuration, Measurement)
- Add separator comments: `# === Connection Keywords ===`
- Document arguments and return values
- Include usage examples in documentation

## Cursor Prompts Library

### Test Development

```
# Create data-driven test
Create a data-driven test in tests/rf_functional.robot that tests
multiple power levels [-20, -10, 0, 5, 10 dBm] at frequency 1 GHz.
Use [Template] keyword approach.

# Add test tags
Review tests/rf_functional.robot and suggest appropriate tags for
each test case based on: category, priority, equipment, feature.

# Optimize test execution
Suggest optimizations for tests/calibration.robot to reduce
execution time while maintaining accuracy.
```

### Infrastructure

```
# Docker optimization
Review Dockerfile and suggest optimizations for:
- Smaller image size
- Faster build times
- Better security

# Jenkins pipeline
Add a new stage to Jenkinsfile that sends email notifications
on test failures, including:
- Failed test count
- Links to HTML reports
- Trend comparison
```

### Documentation

```
# Update docs
Update docs/DEVELOPMENT.md to include a section on testing with
the new PowerMeter equipment, including:
- Configuration steps
- Example test case
- Troubleshooting tips

# Create quick reference
Create a quick reference card (markdown table) for the most
commonly used Robot Framework keywords in this project.
```

## Working with Both Claude Code and Cursor

### Recommended Workflow

1. **Claude Code**: Project setup, infrastructure, architecture decisions
2. **Cursor**: Day-to-day coding, test writing, debugging
3. **Both**: Code review, refactoring, optimization

### Handoff Context

When switching between Claude and Cursor, provide:

**For Cursor**:
```
Working on RF Automation project. Please read:
- PROJECT_SUMMARY.md for overview
- docs/DEVELOPMENT.md for coding standards
- Recent changes in CHANGELOG.md

Current task: [Describe task]
Files involved: [List files]
```

**For Claude Code**:
```
Cursor made changes to [files]. Please review for:
- Consistency with project architecture
- Integration with existing infrastructure
- Documentation completeness
```

## Cursor Composer Tips

### Multi-File Edits

```
Update the following files to add PowerMeter support:

Files:
- resources/network_vars.py (add IP configuration)
- resources/rf_keywords.resource (add keywords)
- tests/power_meter.robot (create test suite)

Requirements:
- Follow existing code patterns
- Maintain backward compatibility
- Add comprehensive documentation
```

### Refactoring

```
Refactor the SCPI communication in resources/rf_keywords.resource:
- Extract common SCPI commands to a separate function
- Add connection pooling for better performance
- Improve error messages
- Maintain all existing functionality
```

## Debugging with Cursor

### Log Analysis

```
Analyze these Robot Framework logs and suggest fixes:

[Paste log excerpt]

Focus on:
- Connection issues
- Timeout problems
- Assertion failures
```

### Performance Issues

```
Tests in tests/calibration.robot are running slowly. Analyze and suggest:
- Redundant equipment resets
- Unnecessary sleep delays
- Optimization opportunities
```

## Git Integration

### Commit Messages

Cursor should generate commits following this format:
```
Type: Brief description

Detailed explanation if needed.

- Bullet points for changes
- Reference issue numbers if applicable
```

Types: `Add`, `Update`, `Fix`, `Docs`, `Refactor`, `Test`

### Branch Naming

For new features: `feature/power-meter-support`
For bugs: `bugfix/connection-timeout`
For docs: `docs/update-setup-guide`

## Testing with Cursor

### Local Testing

```
Help me test this change locally:

1. Build Docker image
2. Run specific test case TC005
3. Verify results
4. Check logs for errors

Provide exact commands to run.
```

### Docker Testing

```
Create a test script that:
- Builds the Docker image
- Runs tests in container
- Validates output.xml
- Reports results

Make it executable and add to scripts/
```

## Advanced Cursor Use Cases

### Code Generation

```
Generate a complete Robot Framework test suite for Vector Network Analyzer:
- Include connection keywords
- S-parameter measurements
- Calibration tests
- Error handling
- Follow project conventions
```

### Migration

```
Migrate this pytest test to Robot Framework:

[Paste pytest code]

Requirements:
- Use project's keyword library
- Match existing test structure
- Maintain test coverage
```

### Analysis

```
Analyze all test files in tests/ and generate:
- Coverage report (which equipment/features tested)
- Test complexity metrics
- Suggestions for improvement
```

## Best Practices for Cursor Prompts

1. **Be Specific**: Reference exact files and line numbers
2. **Provide Context**: Include relevant code snippets
3. **Set Constraints**: Mention compatibility requirements
4. **Reference Standards**: Point to existing patterns to follow
5. **Request Verification**: Ask for explanations of changes

## Resources for Cursor

### Key Files to Reference

- `docs/DEVELOPMENT.md` - Coding standards
- `tests/rf_functional.robot` - Example test suite
- `resources/rf_keywords.resource` - Keyword examples
- `PROJECT_SUMMARY.md` - Quick reference

### Common Patterns

- Test case structure: See `tests/rf_functional.robot:TC001`
- Keyword design: See `resources/rf_keywords.resource:Measure Peak Power`
- Error handling: See `tests/rf_functional.robot:TC008`
- Configuration: See `resources/network_vars.py`

---

## Quick Reference

**Project Type**: RF Test Automation
**Languages**: Robot Framework, Python, Bash, Groovy
**Framework**: Robot Framework 7.0
**Infrastructure**: Docker, Jenkins, Elasticsearch, Kibana
**Target**: RF Equipment (Spectrum Analyzers, Signal Generators, DUT)

**Main Entry Points**:
- Tests: `tests/rf_functional.robot`
- Keywords: `resources/rf_keywords.resource`
- Config: `resources/network_vars.py`
- CI/CD: `Jenkinsfile`

**Development Commands**:
```bash
make help          # Show all commands
make test          # Run tests locally
make docker-build  # Build container
make health-check  # System health
```

---

**Happy coding with Cursor!** 🚀

For questions, consult the comprehensive documentation in `docs/` or the PROJECT_SUMMARY.md.
