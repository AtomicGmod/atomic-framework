# Atomic Framework — Code Style Guide

This document defines the official coding conventions for **Atomic Framework** and all packages built under it.
The goal is simple — **clean, readable, and predictable Lua code**.

---

## 🧱 General Style

- **Indentation:** 2 spaces (no tabs)
- **Line length:** ~100 characters max
- **Encoding:** UTF-8 (no BOM)
- **Trailing whitespace:** none
- **End of file:** one empty line
- **Comments:** short, factual, no essays

---

## 📦 Naming Conventions

| Type | Style | Example |
|------|--------|---------|
| Variables / locals | `camelCase` | `playerData`, `configTable` |
| Functions | `camelCase` | `loadPackage`, `registerCommand` |
| Classes / Objects | `PascalCase` | `Package`, `NetworkService` |
| Constants | `ALL_CAPS` | `DEFAULT_TIMEOUT` |
| Private internals | Prefix `_` | `_resolve_dependencies` |
| Package namespaces | Lowercase, dot-separated | `atomic.config`, `atomic.command` |

## 🧠 OOP Conventions

- Use `:` for instance methods, `.` for static functions.
- Avoid global variables — everything should live under a namespace (`Atomic.*`).
- Keep internal state private whenever possible.
- Don’t mutate other modules’ tables directly.
- Favor composition over inheritance when possible.

---

## 🧩 Documentation & Comments

- Use `--` for single-line comments and `--[[ ... ]]` for multi-line blocks.
- Document **every public function** — parameters and return values.
- Keep comment style consistent and concise.

## 🚫 Don’ts

- ❌ Do **not** use global variables unless absolutely necessary.
- ❌ Do **not** rely on random metatable hacks or implicit magic.
- ❌ Do **not** use inconsistent indentation or mixed styles.

---

## 🧩 Commits & Versioning

Use clear and conventional commit prefixes:

| Type | Description | Example |
|------|------------|---------|
| `feat:` | New feature | `feat(command): add argument parser` |
| `fix:` | Bug fix | `fix(config): prevent nil index in mysql adapter` |
| `refactor:` | Code improvement | `refactor(package): simplify dependency resolver` |
| `docs:` | Documentation changes | `docs(readme): update installation guide` |
| `chore:` | Non-code tasks | `chore: cleanup old debug prints` |