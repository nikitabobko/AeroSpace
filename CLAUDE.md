# Claude Code Instructions

## Workflow

- Always create a PR for any code changes. Do not commit directly to `main`.
- Create a new branch from `main` for each piece of work. Use the naming convention `claude/<short-description>`.
- Build the project before creating the PR to verify it compiles:
  ```
  xcodebuild -project Airlock.xcodeproj -scheme Airlock -configuration Debug build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO -derivedDataPath .xcode-build
  ```
- If the build fails, fix the issue before creating the PR.
- PR against `main`.

## Build

- This is a Swift project built with Xcode (`Airlock.xcodeproj`).
- Use `-derivedDataPath .xcode-build` to keep build artifacts local to the repo.
- Use `CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO` since we don't have signing set up in CI.
