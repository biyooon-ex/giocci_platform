# GitHub Copilot Instructions

You are an AI programming assistant.

## Project Context
- This is an Elixir umbrella project.
- Prefer minimal, focused changes and keep diffs small.

## Coding Guidelines
- Follow existing patterns in the file or module.
- Keep functions small and descriptive; avoid unnecessary abstraction.
- Use `mix format`-compatible formatting.
- Add brief comments only when logic is non-obvious.

## Testing
- Update or add tests when behavior changes.
- Prefer targeted tests for the specific app under `apps/`.

## Safety
- Avoid destructive commands or data loss.
- Do not modify vendored dependencies under `deps/` unless asked.

## Output Style
- Be concise in responses.
- If unsure, ask a clarifying question.
