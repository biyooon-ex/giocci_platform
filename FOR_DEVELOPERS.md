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

**Note**: Since this includes features not supported by the default version of `bash` on macOS, follow the steps below.

```bash
brew install bash
/opt/homebrew/bin/bash ./bin/build_and_push_app_images.sh zenohd
```

## Version Management

### Single Source of Truth: VERSIONS file

All version numbers are managed in the [`VERSIONS`](./VERSIONS) file at the project root:

- `ELIXIR_VERSION` / `ERLANG_VERSION` / `UBUNTU_VERSION` — used as `ARG` defaults in all Dockerfiles and as build args in docker-compose files
- `ZENOH_VERSION` — used as `ARG` in the root Dockerfile and image tags
- `ZENOHEX_VERSION` — used directly in `apps/giocci_engine/mix.exs` and `apps/giocci_relay/mix.exs`
- `PROJECT_VERSION` — used in root `mix.exs`, `apps/giocci_engine/mix.exs`, `apps/giocci_relay/mix.exs`, and `apps/giocci_integration_test/mix.exs`

> **Note**: `apps/giocci/mix.exs` still has hardcoded versions for hex.pm compatibility. Update it alongside `VERSIONS` when releasing.

### Running Docker Compose with VERSIONS

The docker-compose files use `${VAR}` variable substitution. Pass `VERSIONS` as the env file:

```bash
# From the project root (for zenohd):
docker compose --env-file VERSIONS up

# From an app directory (e.g., for giocci):
docker compose --env-file ../../VERSIONS up
```

The `./bin/build_and_push_app_images.sh` script handles this automatically.

### Check Version Consistency

Ensure all version numbers are consistent across the project:

```bash
./bin/check_version_consistency.exs
```

This script verifies that version numbers in `mix.exs`, `VERSIONS`, Dockerfiles, docker-compose files, and other configuration files are consistent.

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

Publish the giocci package to Hex.pm:

```bash
cd apps/giocci
mix hex.publish
```

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
   - Update `VERSIONS` (all version numbers are managed there)
   - Also update `apps/giocci/mix.exs` (hardcoded for hex.pm compatibility)
   - Also update `.github/workflows/ci.yml` zenohd image tag if `ZENOH_VERSION` changed
   - Build and push Docker images: `./bin/build_and_push_app_images.sh all`
   - Publish to Hex: `cd apps/giocci && mix hex.publish`

## Versioning

We will increment the minor version of this package/repository when the following updates are happend.

- Adds a new API to giocci (Client)
- Bumps minor version for Zenoh/Zenohex

We will increment the patch version of this package/repository when the following updates are happend.

- Bug fixes existing APIs and features
- Bumps patch version for Zenoh/Zenohex
- Other necessary corrections
