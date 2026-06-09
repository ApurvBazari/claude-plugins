_Rendered as markdown because walkthrough is not installed — install it for the interactive HTML review._

# Review — Authentication Login Handler

**Verdict: fix**  ·  new

This review covers the modification to `src/auth/login.ts` introduced in the current branch. The change adds a login handler to the authentication module. One high-severity correctness finding was identified and verified: a password comparison using `==` permits type coercion and must be replaced with a constant-time strict comparison. The spec item requiring rate-limiting of login attempts remains unimplemented. The plan step to add a login handler was followed.

## Adherence

| Item | Kind | State |
|---|---|---|
| Validate credentials | spec | met |
| Rate-limit attempts | spec | missing |
| Add login handler | plan | followed |

## High

- **F1: Password compared with == allowing type coercion** — `src/auth/login.ts:42`  ·  _new_ · verified
  - Claim: Password compared with == allowing type coercion
  - Detail: Use a constant-time strict comparison; == permits type juggling. An attacker can craft an input that coerces to the expected password value, bypassing authentication entirely.
  - Fix: Use timingSafeEqual on Buffers

## Risk

| File | Change | Risk |
|---|---|---|
| src/auth/login.ts | modified | auth |
