# GitHub workflow

Use a private repository for development where appropriate; this patch changes no repository settings.
Do not commit passwords, tokens, real records or database storage directories.

## Start
With a clean working tree:
```sh
git switch main
git pull --ff-only origin main
git switch -c feature/your-task
```

## Commit and review
Review git diff, stage explicit paths, inspect git diff --cached, commit, then:
```sh
git push -u origin feature/your-task
```
Open a PR. The other member checks relevant SQL, rebuilds and tests before approval.
Keep main buildable; no force-push to main. Resolve conflicts together and retest.
Agree one coordinator at a time for shared schema/seed edits.

## Data
Git shares files, not live database changes. Promote durable data into reviewed seed SQL.
Do not rerun non-idempotent seed SQL over populated data. Preserve local work before resets.
Rebuild only a known disposable development database using the documented setup procedure.
