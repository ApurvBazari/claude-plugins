_Rendered as markdown because walkthrough is not installed — install it for the interactive HTML review._

# Review — Authentication Login Handler

**Verdict: block**  ·  new

This review covers the modification to `src/auth/login.ts` introduced in the current branch. The change adds a login handler to the authentication module. A high-severity correctness finding was identified and verified: a password comparison using `==` permits type coercion and must be replaced with a constant-time strict comparison — it drives the escalation to `major`, so the verdict is `block`. A medium spec-gap was also found and verified: the required rate-limiting of login attempts remains unimplemented. The plan step to add a login handler was followed.

## Adherence

| Item | Kind | State |
|---|---|---|
| Validate credentials | spec | met |
| Rate-limit attempts | spec | missing |
| Add login handler | plan | followed |

## High

- **F2: Password compared with == allowing type coercion** — `src/auth/login.ts:42`  ·  _new_ · verified
  - Claim: Password compared with == allowing type coercion
  - Detail: Use a constant-time strict comparison; == permits type juggling. An attacker can craft an input that coerces to the expected password value, bypassing authentication entirely.
  - Fix: Use crypto.timingSafeEqual on Buffers derived from the input and stored hashes

## Medium

- **F1: Rate-limiting requirement not implemented** — `src/auth/login.ts`  ·  _new_ · verified
  - Claim: The spec requires rate-limiting of login attempts, but no rate-limit logic exists in the implementation.
  - Detail: The spec item 'Rate-limit attempts' is a hard requirement to prevent brute-force attacks; the login handler makes no attempt to track failed attempts, enforce a lockout threshold, or return 429 responses.
  - Fix: Add a sliding-window rate limiter keyed on IP + username; return HTTP 429 with Retry-After once the threshold is exceeded.

## Risk

| File | Change | Risk |
|---|---|---|
| src/auth/login.ts | modified | auth |
