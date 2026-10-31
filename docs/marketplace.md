# Marketplace release readiness

Preparation is tracked in [#39](https://github.com/jkvithanage/omarchy-github-stats/issues/39). The repository remains private and no marketplace submission has been created. Public visibility and submission each require final owner approval.

## Release identity

The annotated [`v1.0.0` tag](https://github.com/jkvithanage/omarchy-github-stats/tree/v1.0.0) points to `26281cd24a1b22bdbc61ff5198d8467fa5d6adb5`, merged through [#38](https://github.com/jkvithanage/omarchy-github-stats/pull/38). Its manifest declares `1.0.0`. Marketplace packaging follows in separate commits; the tag is not moved. The permanent plugin ID remains `omarchy-github-stats`.

V1 remains read-only and uses the native bar widget and one host-managed service. Notifications Inbox work in #35/#36 is outside this release. The project is MIT licensed; its runtime dependencies are Omarchy/Quickshell and an authenticated GitHub CLI. Development dependencies are documented in the README.

## Marketplace requirements

Checked on 2026-10-31 against marketplace revision `c752dd16a2d6fbaab9bf8c3cc5834e27953e0183`:

| Requirement | Evidence or remaining gate |
| --- | --- |
| Public, active GitHub repository | Private; awaiting owner approval to change visibility |
| One root plugin manifest with supported kinds and safe entry points | Native validator and marketplace community-manifest validation pass |
| Root README with installation, removal and dependency guidance | README includes all three |
| Root license | MIT `LICENSE` |
| Globally unique ID outside `omarchy.*` | `omarchy-github-stats` absent from active/retired IDs at the inspected marketplace revision; recheck before submission |
| No symlinks inside the distributed plugin | Host validator checks this; the development installation's outer symlink is not distributed |
| Optional root preview | `preview.png`, 592 × 664 pixels, captured from the unchanged widget using synthetic fixture data |
| Exact-commit compatibility and security reports | Public-repository validation remains gated on visibility approval |

The marketplace accepts version `1.0.0` and combined `bar-widget`/`service` kinds. A namespaced ID is preferred but optional. Listing category **Developer Tools** and tags **bar**, **quickshell** are separate from the manifest's native-bar category **Development**.

Primary sources:

- [Submission requirements and owner approval](https://github.com/omacom/omarchy-plugin-marketplace/blob/c752dd16a2d6fbaab9bf8c3cc5834e27953e0183/SUBMISSION.md)
- [Compatibility validator](https://github.com/omacom/omarchy-plugin-marketplace/blob/c752dd16a2d6fbaab9bf8c3cc5834e27953e0183/scripts/build-catalog.mjs)
- [Static security policy](https://github.com/omacom/omarchy-plugin-marketplace/blob/c752dd16a2d6fbaab9bf8c3cc5834e27953e0183/SECURITY.md)
- [Native Omarchy plugin contract](https://github.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins.md)

## Verification and public-content review

See the [verification record](verification.md) for automated, lifecycle and desktop evidence. Unavailable screen-reader and two-physical-monitor observations remain disclosed limitations.

A limited credential-pattern review inspected 195 historical blobs among 386 reachable Git objects, issue/PR descriptions #1–#39, 32 discussion comments and four inline PR comments on 2026-10-31. It found no GitHub tokens, AWS access keys, private-key blocks or credential-bearing HTTP URLs. This records the checked patterns, not a comprehensive secret scan or security audit. The marketplace preparation PR is reviewed separately as part of its normal diff and CI checks.

Making the repository public also exposes commit author identities/emails, engineering discussions, local paths in historical documentation, and the open v2 Inbox design. Review those disclosures before approval. Existing CI runs fixture tests and does not fetch production account data. The preview contains only synthetic account `fixture` and aggregate fixture values.

## Remaining publication gates

1. Review the merged preparation changes and the disclosures above, then obtain owner approval to make this existing repository public.
2. Verify unauthenticated repository access and recheck the plugin ID against current active and retired IDs.
3. From a checked marketplace checkout with Node 24+ and its locked dependencies installed, run its compatibility validator and security baseline against the submission commit:

   ```sh
   VALIDATION_METADATA_PATH=/tmp/github-stats-validation.json \
     node scripts/validate-submission.mjs \
     --repo=https://github.com/jkvithanage/omarchy-github-stats
   node scripts/security-baseline.mjs \
     --metadata=/tmp/github-stats-validation.json \
     --json=/tmp/github-stats-security.json
   ```

   Confirm that the reported commit matches the intended current master. Inspect the baseline JSON outcome and findings; a successful process exit alone does not mean the baseline passed. Resolve blocking findings and disclose any findings requiring maintainer review. Repeat exact-commit checks if the submission code changes.
4. Show the completed title and body below to the owner. Confirm every checklist statement and obtain explicit submission approval before creating an issue in `omacom/omarchy-plugin-marketplace`. Set all five boxes to checked only once every statement is true and confirmed.

Marketplace maintainers determine any `manual-setup` classification and apply `approved-and-verified` after reviewing the exact commit's reports. Later upstream commits need renewed snapshot verification; the Git tag does not grant marketplace verification.

## Submission draft

Title: `[Plugin]: Omarchy GitHub Stats`

The body is prepared below, with all confirmations left unchecked pending public validation and owner review:

```markdown
### Repository URL

https://github.com/jkvithanage/omarchy-github-stats

### Category

Developer Tools

### Tags

bar, quickshell

### Suggest a missing tag

_No response_

### Maintainer notes

Native bar widget for personal GitHub contributions, repository snapshots, pull requests and issues. Requires the native omarchy.bar and GitHub CLI (gh), authenticated for github.com and available on the running shell process's PATH. Users complete gh auth login --hostname github.com in a terminal; the plugin never starts an interactive login. Replacement bars are not supported. Please assess whether these prerequisites require the manual-setup label.

The plugin makes read-only GitHub requests through asynchronous gh processes. Credentials remain managed by gh; account data stays in memory and is not logged or persisted by the plugin. preview.png uses synthetic fixture data. Verified host versions and remaining accessibility/multi-monitor limitations are documented in docs/verification.md.

### Submission checklist

- [ ] The repository is public and contains installation and removal instructions.
- [ ] I have documented the plugin license and any external dependencies.
- [ ] I confirm that I own or have permission to submit this plugin and its preview assets.
- [ ] The plugin does not overwrite user configuration without explicit consent.
- [ ] I understand that approval is for listing and is not a security review.
```
