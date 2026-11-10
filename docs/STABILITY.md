# Stability

This page covers which parts of Riffer you can depend on, how changes to them are announced, and how breaking releases work. Riffer is not at 1.0 yet; the [roadmap](https://github.com/janeapp/riffer/issues/528) tracks the path there.

## Public API

The public API is everything documented in these guides. You can build on it, and it changes only in the ways this page describes.

Everything else is internal, even when Ruby lets you reach it. That includes classes, methods and constants that appear in the [API reference](https://riffer.ai/api/) but not in a guide. Internal code can change in any release without notice. At 1.0, every public constant will be documented and everything else marked private.

## Experimental features

Experimental features are labelled _experimental_ in the guides, like the [prompted structured output strategy](AGENTS.md#structured-output-strategy-experimental). They can change in any minor release, and the [CHANGELOG](https://github.com/janeapp/riffer/blob/main/CHANGELOG.md) notes each change.

## Deprecations

A breaking change to the public API lands first as a new API or an [opt-in flag](CONFIGURATION.md#future-flags), and the old way prints a deprecation warning. The warning appears for at least one release before the old way is removed. For larger changes, it also names a date it won't be removed before. The CHANGELOG and [UPGRADING.md](https://github.com/janeapp/riffer/blob/main/UPGRADING.md) say which release removes it.

## Breaking releases

Before 1.0, any minor release can include breaking changes, but never without notice: an earlier release deprecates what's changing first, so you'll see the warnings before anything breaks. Each breaking release comes with an upgrade guide in [UPGRADING.md](https://github.com/janeapp/riffer/blob/main/UPGRADING.md), and the CHANGELOG lists its changes under **⚠ BREAKING CHANGES**.

After 1.0, breaking changes ship only in major versions.

## Saved formats

Saved formats are the data Riffer produces for you to store and load later, such as [serialized agents](SERIALIZATION.md) and [messages persisted with `to_h`](MESSAGES.md#parts).

- Riffer can read a new format at least one release before it starts writing it, so a deploy that runs a release alongside the one before it keeps working.
- Anything saved by a 1.x release loads in every later 1.x release.

See [Serialization → Versioning](SERIALIZATION.md#versioning) for how agent data records its format version.
