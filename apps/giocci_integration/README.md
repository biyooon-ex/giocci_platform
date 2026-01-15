# GiocciIntegration

Integration test suite for Giocci.

This application contains integration tests that verify the interaction between
Giocci components (client, relay, and engine). It includes a test module
(`GiocciIntegration`) that is used to test module distribution and remote
execution across the system.

## Running Tests

From the project root:

```bash
./bin/test.sh
```

## Test Coverage

- Client registration with relay
- Module saving and distribution
- Function execution on remote engines
- Asynchronous function execution
- Error handling when components are unavailable
