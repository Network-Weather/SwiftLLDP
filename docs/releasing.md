# Releasing SwiftLLDP

This document captures the recommended steps for cutting a release.

1. **Update version metadata**
   - Bump versions in `Package.swift` and any example packages if required.
   - Update `CHANGELOG.md` with a summary of notable changes.

2. **Run automation locally**
   ```bash
   ./Scripts/lint.sh
   ./Scripts/format.sh
   ./Scripts/test.sh
   ./Scripts/docs.sh .build/docc SwiftLLDP
   ```

3. **Create a release branch**
   ```bash
   git checkout -b release/vX.Y.Z
   git commit -am "Prepare vX.Y.Z"
   ```

4. **Open a pull request** and ensure GitHub Actions completes successfully.

5. **Tag the release** after merging to `main`:
   ```bash
   git tag -a vX.Y.Z -m "SwiftLLDP vX.Y.Z"
   git push origin vX.Y.Z
   ```

6. **Publish documentation**
   - Download the DocC artifact from the CI run for the release commit.
   - Host it via GitHub Pages, Netlify, or the Swift Package Index documentation
     uploader.

7. **Announce** in the chosen channels (release notes, blog posts, or the
   project discussion board).

Following these steps keeps the Swift Package Index metadata, documentation, and
source tags aligned.
