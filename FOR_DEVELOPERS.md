# For Developers

This document provides instructions for developers working on the Giocci project.

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

The CI environment uses a Docker image built from the root `Dockerfile` and `docker-compose.yml` for the `zenohd` service.

To build and push the CI image:

```bash
docker compose build zenohd
docker compose push zenohd
```

**Note**: This image is used by GitHub Actions for running tests in CI.

## Version Management

### Check Version Consistency

Ensure all version numbers are consistent across the project:

```bash
./bin/check_version_consistency.exs
```

This script verifies that version numbers in `mix.exs`, `VERSIONS`, and other configuration files match.

## Building and Publishing

### Build and Push Docker Images

Build and push all application Docker images (giocci_client, giocci_relay, giocci_engine):

```bash
./bin/build_and_push_app_images.sh
```

This script:
1. Builds Docker images for each application
2. Tags them with the current version
3. Pushes them to the container registry

### Publish to Hex

Publish the giocci_client package to Hex.pm:

```bash
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
   - Update version numbers
   - Build and push Docker images: `./bin/build_and_push_app_images.sh`
   - Publish to Hex: `mix hex.publish`