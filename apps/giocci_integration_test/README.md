# GiocciIntegrationTest

Integration test suite for GiocciPlatform.

This application contains integration tests that verify the interaction between
GiocciPlatform components (client, relay, and engine). It includes a test module
(`GiocciIntegrationTest`) that is used to test module distribution and remote
execution across the system.

## Running Tests

From the project root:

```bash
mix test
```

This command automatically detects your environment and runs all integration tests appropriately.

## Test Coverage

- Client registration with relay
- Module saving and distribution
- Function execution on remote engines
- Asynchronous function execution
- Error handling when components are unavailable
