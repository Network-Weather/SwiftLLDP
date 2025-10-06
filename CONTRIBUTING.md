# Contributing

Thank you for considering contributing to SwiftLLDP! We welcome improvements,
bug reports, and feature ideas from the community.

## Getting Started

1. Fork the repository and create a feature branch from `main`.
2. Install development tooling:
   - Xcode 15.4 or newer (for Swift 6.2 toolchain)
   - `swift-format` 0.51.0 or newer if you plan to format locally
3. Run `./Scripts/bootstrap.sh` to install pre-commit hooks (optional).

## Development Workflow

- Keep changes focused and covered by unit tests where possible.
- Run `./Scripts/format.sh` before submitting a pull request.
- Execute `./Scripts/test.sh` locally and ensure it passes.
- Update documentation (`README.md`, docs/, DocC catalog) when user-facing
  behavior changes.

## Commit Guidelines

- Follow conventional commits (e.g., `feat: add TLV decoding`).
- Keep commit messages concise but descriptive.

## Pull Request Checklist

- [ ] Tests pass locally.
- [ ] Code is formatted with `swift-format`.
- [ ] Documentation is updated when behavior or public APIs change.
- [ ] New APIs include doc comments and, when relevant, examples.

By participating you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).
