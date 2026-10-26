# GitHub flow

`master` is the integration branch. Ticket implementations reach it through pull requests.

1. **Branch.** Start from current `origin/master` in a clean checkout. Name ticket branches `<type>/<number>-<slug>`, for example `feat/1-native-contributions`. Use `feat`, `fix`, `docs`, or `chore`; keep the slug lowercase with hyphens. Unticketed maintenance uses `docs/<slug>` or `chore/<slug>`. Done when the branch contains the ticket number and is based on the fetched integration branch.
2. **Implement.** Follow the ticket and repository guidance. Run applicable checks before committing; once the plugin exists, `make check` is the local gate and `make smoke` verifies changes affecting native shell behavior. Done when the implementation and focused verification satisfy the ticket, with any verification limits recorded.
3. **Publish.** Commit on the work branch, push it with upstream tracking, and open a PR targeting `master`. Include `Closes #<number>` for a completed ticket, describe the behavior and validation, and record remaining risks. Done when the PR links the ticket and its diff contains only the intended work.
4. **Integrate.** Address review findings and require the PR's current CI checks to pass. Update a stale branch against `origin/master` and rerun affected checks. Merge through the PR when the user authorizes merging. Done when GitHub reports the PR merged into `master`.
5. **Sync.** Fetch the merged result, fast-forward local `master`, and remove the merged work branch when it is no longer needed. Done when local `master` matches `origin/master` and retained local work is accounted for.

Keep shared history intact: use ordinary pushes for published branches. If rebasing would rewrite a published branch, get explicit authorization for that rewrite; otherwise merge the updated `origin/master` into it. An explicitly requested bootstrap commit on `master` is a one-time exception to the PR path.

The workflow in `.github/workflows/ci.yml` defines the automated checks. Native compositor smoke tests run in a local Hyprland session; hosted CI does not replace that verification.
