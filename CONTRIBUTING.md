# Contributing to RF Automation Infrastructure

Thank you for contributing to the RF Automation Infrastructure project!

## Development Process

1. **Fork & Clone**
   ```bash
   git clone <repository-url>
   cd Fully_Product_Automation
   ```

2. **Create Feature Branch**
   ```bash
   git checkout develop
   git checkout -b feature/your-feature-name
   ```

3. **Make Changes**
   - Write tests following Robot Framework best practices
   - Add documentation for new features
   - Update relevant .md files

4. **Test Locally**
   ```bash
   # Test Robot Framework syntax
   robot --dryrun tests/

   # Run tests
   robot --outputdir results tests/your_test.robot

   # Build Docker image
   docker build -t rf-test-runner .

   # Test in container
   docker run --rm --network host \
       -v $(pwd)/results:/app/results \
       rf-test-runner --outputdir results tests/your_test.robot
   ```

5. **Commit Changes**
   ```bash
   git add .
   git commit -m "Add: Brief description of changes"
   ```

   **Commit Message Format**:
   - `Add: New feature or test`
   - `Update: Modify existing feature`
   - `Fix: Bug fix`
   - `Docs: Documentation changes`
   - `Refactor: Code refactoring`

6. **Push & Create Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```

   Create PR targeting `develop` branch

## Code Standards

### Robot Framework Tests

- Use descriptive test case names
- Add comprehensive documentation
- Include appropriate tags
- Follow naming convention: `TC###: Descriptive Name`
- Add units in comments for numeric variables

### Python Code

- Follow PEP 8 style guide
- Use type hints where appropriate
- Add docstrings to functions
- Use meaningful variable names

### Documentation

- Update relevant .md files
- Include examples where applicable
- Keep documentation synchronized with code

## Testing Requirements

All contributions must:
- [ ] Pass Robot Framework dry run
- [ ] Execute successfully in Docker container
- [ ] Include test documentation
- [ ] Not break existing tests

## Code Review

All PRs require:
- Automated Jenkins build passing
- Code review approval from team member
- No merge conflicts with target branch

## Questions?

Contact the automation team or create an issue in the repository.
