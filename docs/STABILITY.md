# Stability

This page covers which parts of Riffer you can depend on, how changes to them are announced, how breaking releases work, and which gems this repo maintains. Riffer is not at 1.0 yet; the [roadmap](https://github.com/janeapp/riffer/issues/528) tracks the path there.

## Public API

The public API is everything documented in these guides. You can build on it, and it changes only in the ways this page describes.

Everything else is internal, even when Ruby lets you reach it. That includes classes, methods and constants that appear in the [API reference](https://riffer.ai/api/) but not in a guide. Internal code can change in any release without notice. At 1.0, every public constant will be documented and everything else marked private.

## Experimental features

Experimental features are labelled _experimental_ in the guides, like the [prompted structured output strategy](AGENTS.md#structured-output-strategy-experimental). They can change in any minor release, and the [CHANGELOG](https://github.com/janeapp/riffer/blob/main/riffer-core/CHANGELOG.md) notes each change.

## Deprecations

A breaking change to the public API lands first as a new API or an [opt-in flag](CONFIGURATION.md#future-flags), and the old way prints a deprecation warning. The warning says the old way will be removed in a future version, and it appears for at least one release before that happens.

## Breaking releases

Before 1.0, any minor release can include breaking changes, but never without notice: an earlier release deprecates what's changing first, so you'll see the warnings before anything breaks. Each breaking release comes with an upgrade guide in [UPGRADING.md](https://github.com/janeapp/riffer/blob/main/UPGRADING.md), and the CHANGELOG lists its changes under **⚠ BREAKING CHANGES**.

After 1.0, breaking changes ship only in major versions.

## Saved formats

Saved formats are the data Riffer produces for you to store and load later, such as [serialized agents](SERIALIZATION.md) and [messages persisted with `to_h`](MESSAGES.md#parts).

- Riffer can read a new format at least one release before it starts writing it, so a deploy that runs a release alongside the one before it keeps working.
- Anything saved by a 1.x release loads in every later 1.x release.

See [Serialization → Versioning](SERIALIZATION.md#versioning) for how agent data records its format version.

## Packages

Jane maintains every gem in this repo, releases them all through the same pipeline, and covers each one with the policies on this page. Each gem has its own version and is released separately.

| Gem      | What it covers                     | Owner              |
| -------- | ---------------------------------- | ------------------ |
| `riffer` | The core framework in these guides | `@janeapp/jane-ai` |

### Adding a gem

A gem joins this repo only when all of these hold:

- Jane uses it in production.
- It builds on Riffer's public extension points, such as [tools](TOOLS.md), hooks, [providers](providers/CUSTOM_PROVIDERS.md) and [saved runs](#saved-formats), rather than a specific vendor or app concern.

### Retiring a gem

If a gem loses its owner or Jane stops using it, it's deprecated for at least one release. After that, it's handed to a community maintainer or archived.

### Community gems

Anything else is welcome as a community gem. See [Community Gems](COMMUNITY_GEMS.md) for the ones we know about and how to add yours.
