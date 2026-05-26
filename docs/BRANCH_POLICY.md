# Branch policy (R09)

## Protected branch: `main`

| Rule | Requirement |
|------|-------------|
| Merge method | Pull request only (no direct pushes when enforced on GitHub) |
| CI | `.github/workflows/ci.yml` must be green (`analyze` + `test`) |
| Review | At least 1 approval (solo dev: self-review via PR checklist) |
| Secrets | Never commit `secrets.json`, `google-services.json`, keystores |

## Workflow

1. Branch from `main`: `feature/phase8-r01-jwt` etc.
2. One logical commit per audit task when possible.
3. Open PR → wait for CI → merge.
4. Tag releases: `v1.0.0-rc1` after Phase 8 sign-off.

## Baseline tag

`pre-phase8-baseline` — last commit before Phase 8 security commits (`ea73252`).

History rewrite for R01 JWT purge: feature branch only; see `docs/GIT_HISTORY_REWRITE.md`.
