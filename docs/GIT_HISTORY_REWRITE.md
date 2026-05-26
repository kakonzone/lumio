# Git history rewrite — R01 JWT removal

## Why

`lib/provider/app_provider.dart` previously contained a live `subscriberToken` JWT in plain text (audit R01). Removing it from **current** tree is not enough if the token remains in git history.

## Manual actions (required)

1. **Rotate the Toffee subscriber token** at the provider — the leaked JWT must be treated as compromised.
2. Store the new value only in local `secrets.json` as `TOFFEE_SUBSCRIBER_TOKEN` (never commit).

## Inspect history

```bash
git log --all --oneline -- lib/provider/app_provider.dart
git log -p --all -S 'subscriberToken=eyJ' -- lib/provider/app_provider.dart
```

## Rewrite options (feature branch only — never force-push `main` without team sign-off)

### Option A: `git filter-repo`

1. Install: `pip install git-filter-repo`
2. Create `replacements.txt` **locally** (do not commit) with the exact leaked substring replaced by `REDACTED`:

   ```
   literal:eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.==>REDACTED
   ```

   Add additional lines for every unique fragment that appears in history.

3. Run from repo root:

   ```bash
   git tag pre-phase8-baseline   # if not already tagged (see Phase 8 Task 6)
   git filter-repo --replace-text replacements.txt
   ```

4. Push rewritten history to a **new** remote branch:

   ```bash
   git push -u origin HEAD:security/r01-history-rewrite --force
   ```

5. Open PR; retire old clones; require fresh clone or `git fetch --all` + reset.

### Option B: BFG Repo-Cleaner

```bash
bfg --replace-text replacements.txt
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

## Verification after rewrite

```bash
git log -p --all -S 'eyJhbGciOi' -- lib/ | head
# Expect: no output
```

## Current-tree verification (automated)

```bash
grep -rn 'eyJhbGciOi' lib/ || echo 'lib/ clean'
flutter test test/security/no_secrets_in_lib_test.dart
```
