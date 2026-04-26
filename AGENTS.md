# AGENTS.md

## Design principles

- **KISS (Keep It Simple, Stupid).** Prefer straightforward solutions. Avoid over-engineering and unnecessary complexity — readable, maintainable code beats clever code.
- **YAGNI (You Aren't Gonna Need It).** Implement only what's needed now. Don't add speculative features, options, or abstractions for hypothetical future needs.
- **SOLID.** Apply the five principles when shaping modules and interfaces:
  - *Single Responsibility* — each module has one reason to change.
  - *Open-Closed* — extend behavior without modifying existing code.
  - *Liskov Substitution* — subtypes honor the contracts of their base types.
  - *Interface Segregation* — callers depend only on the surface they use.
  - *Dependency Inversion* — depend on abstractions, not concrete implementations.

## Style guides

- [llm-docs/process/luau-style.md](llm-docs/process/luau-style.md) — Luau (Roblox plugin).
- [llm-docs/process/react-patterns.md](llm-docs/process/react-patterns.md) — React (Roblox plugin).