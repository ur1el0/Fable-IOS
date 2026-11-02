# ADR 0001: Versioned password hashes with login-time upgrades

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

Accounts currently store PBKDF2-HMAC-SHA256 hashes using 100,000 iterations and an implicit `salt$hash` representation. Raising the work factor must preserve sign-in for existing users and must allow future parameter changes without another database schema migration.

## Decision

New credentials use a self-describing `pbkdf2_sha256$iterations$salt$digest` representation with a 16-byte random salt and 600,000 iterations. Verification continues to recognize the legacy `salt$hash` representation at its original 100,000 iterations. After a successful legacy or weaker-hash login, the service computes the current hash and updates the row only if the stored value has not changed concurrently.

## Consequences

- Existing users are upgraded on their next successful login; no plaintext password or bulk reset is required.
- The existing `password_hash` column and SQLite schema remain unchanged.
- A concurrent credential change cannot be overwritten by the login-time upgrade because the update compares the prior hash.
- PBKDF2 remains available from Python's standard library, avoiding a new runtime dependency. Future algorithms or work factors can be represented explicitly and migrated through the verifier.
- Login work increases to the current PBKDF2 cost. Authentication rate limits remain part of the request boundary.
