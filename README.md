# Giocci

**TODO: Add description**

## How to build and push docker image

```bash
docker compose build zenohd
docker compose push zenohd
```

## How to test

```bash
./bin/test.sh
```

## How to update zenoh version

1. Update zenohex versions in each mix.exs
2. Update zenoh version in Dockerfile and image tag in docker-compose.yml
3. Update image tag in .github/workflows/ci.yml
