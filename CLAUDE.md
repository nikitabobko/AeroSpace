# Claude Code Instructions

## Workflow

- Always create a PR for any code changes. Do not commit directly to `main`.
- Create a new branch from `main` for each piece of work. Use the naming convention `claude/<short-description>`.
- After making code changes, build and deploy the app by running `./deploy.sh`.
- If the build fails, fix the issue before creating the PR.
- PR against `main`.

## Build & Deploy

- This is a Swift project built with Xcode (`Airlock.xcodeproj`).
- `./deploy.sh` builds a Release build, copies it to `/Applications/Airlock.app`, and launches it.
- Use `-derivedDataPath .xcode-build` to keep build artifacts local to the repo.
- Use `CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO` since we don't have signing set up.
