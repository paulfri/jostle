# Contributing to Jostle

Issues and pull requests are welcome.

## Before opening a change

- Keep Jostle focused on modifier-drag window movement and resizing.
- Search existing issues and pull requests for related work.
- Describe the macOS version, app type, and reproduction steps for behavioral bugs.

## Development

1. Create a branch from `main`.
2. Make the smallest coherent change.
3. Run the test suite:

   ```sh
   xcodebuild \
     -project Jostle.xcodeproj \
     -scheme 'Jostle Development' \
     -destination 'platform=macOS' \
     -derivedDataPath build-tests \
     CODE_SIGNING_ALLOWED=NO \
     test
   ```

4. Include focused Swift tests for policy, settings, and adapter behavior where practical.
5. Open a pull request explaining the behavior change and verification performed.

Local builds should use the isolated Jostle Development profile. Public artifacts follow the Developer ID and notarization process documented in [`docs/releasing.md`](docs/releasing.md).
