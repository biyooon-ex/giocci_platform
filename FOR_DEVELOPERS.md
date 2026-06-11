# For Developers

This document provides instructions for developers working on the GiocciPlatform project.

## Testing

### Local Testing

Run all tests locally:

```bash
mix test
```

This command automatically detects your environment and runs tests appropriately:
- If Docker is available: runs tests in a containerized environment with Zenoh daemon
- If running inside a container: executes tests directly with background Zenoh daemon

### CI Docker Image

The CI environment, which also runs on GitHub Actions, uses a Docker image built from the root `Dockerfile` and `docker-compose.yml` for the `zenohd` service.

To build and push the CI image:

```bash
./bin/build_and_push_app_images.sh zenohd
```

**Note**: Since this includes features (e.g., `declare -A`) that are not supported by the default version of `bash` (3.2) on macOS, follow the steps below.

```bash
brew install bash
/opt/homebrew/bin/bash ./bin/build_and_push_app_images.sh zenohd
```

## Version Management

### Check Version Consistency

Ensure all version numbers are consistent across the project:

```bash
./bin/check_version_consistency.exs
```

This script verifies that version numbers in `mix.exs`, `VERSIONS`, and other configuration files match.
Also, this script will be executed in CI on GitHub Actions.

## Versioning Rule

We will increment the minor version of this package/repository when the following updates are happend.

- Adds a new API to giocci (Client)
- Bumps major/minor version for Zenoh/Zenohex
- Changes in usage affecting users and operators

We will increment the patch version of this package/repository when the following updates are happend.

- Bug fixes existing APIs and features
- Bumps patch version for Zenoh/Zenohex
- Other necessary corrections

### Update version

When updating this project itself or the versions of Zenoh, Elixir, and other dependencies, we must also update the contents of the root `VERSIONS` file.

The umbrella applications read the root `VERSIONS` file when needed. Only `apps/giocci` temporarily receives a copied `VERSIONS` file during Hex publishing so that the file can be included in the package tarball.

## Building and Publishing

### Build and Push Docker Images

Build and push all application Docker images (giocci, giocci_relay, giocci_engine):

```bash
./bin/build_and_push_app_images.sh giocci giocci_relay giocci_engine
```

This script:
1. Builds Docker images for each application
2. Tags them with the current version
3. Pushes them to the container registry

### Publish to Hex

When creating a new tag or release, `apps/giocci` (the client API library) is automatically published to Hex.pm as a Hex package by `./github/workflows/publish2hex.yml`.

If a issue occurs and we need to run this manually, proceed as follows to publish the giocci package to Hex.pm from the local:

```bash
./bin/publish_giocci_to_hex.sh
```

This script temporarily copies the root `VERSIONS` file into `apps/giocci/`, runs `mix hex.publish`, and removes the copied file afterward.

**Prerequisites**:
- Ensure version numbers are consistent (run `./bin/check_version_consistency.exs`)
- Update CHANGELOG if applicable
- Ensure all tests pass

## Development Workflow

1. Make changes to the code
2. Run tests locally: `mix test`
3. Check version consistency: `./bin/check_version_consistency.exs`
4. Commit and push changes
5. CI will automatically run tests
6. For releases:
   - Update version numbers
   - Build and push Docker images: `./bin/build_and_push_app_images.sh all`
   - Publish to Hex: `./bin/publish_giocci_to_hex.sh`
