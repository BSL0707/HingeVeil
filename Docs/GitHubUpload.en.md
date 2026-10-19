# GitHub upload guide

[한국어](GitHubUpload.ko.md) · [README](../README.md)

Target: HingeVeil 0.1.11 source · public credit: **bsl lab** · [MIT](../LICENSE).

This guide does not create a repository, commit, upload or change visibility. Apple Developer enrollment, paid signing and notarization are excluded from this source-upload task. Source hosting and application distribution are separate.

## 1. Use only the separated folder

Extract the GitHub source ZIP and use its `HingeVeil` folder. Upload the extracted files, including hidden `.github` and `.gitignore`, not merely the ZIP itself. Command+Shift+Period toggles hidden files in Finder.

Never upload the parent development workspace, legacy macTilt projects, comparison checkouts, personal screen videos, backups, diagnostics, `.build` or `Build`. The source ZIP contains no app binary, certificates or previous Git history. The original installed app is not replaced.

## 2. Check locally

First verify the terminal is in the **separated HingeVeil folder**:

```sh
pwd
bash scripts/ci.sh
```

Full Xcode and Python 3.10+ are required. Local ad-hoc signing uses no paid certificate or Apple account. These checks do not start a lid sensor, real desktop capture or permission reset. GPU/physical-lid testing is separate.

## 3. Prepare a new repository

Create an **empty repository** named `HingeVeil` on GitHub. Starting privately to review the files is recommended. Do not generate another README, LICENSE or .gitignore. Replace `OWNER` below with the actual GitHub account/organization. These are instructions, not automatically executed commands.

Commits record the author email. Find your own no-reply address in GitHub's email settings and replace the placeholder below. Do not publish a real name/private email unintentionally. Never embed a token or password in a remote URL.

```sh
git init -b main
git config --local user.name "bsl lab"
git config --local user.email "YOUR_GITHUB_NOREPLY_ADDRESS"
git config --local core.logAllRefUpdates true
git add --dry-run .
git add .
python3 scripts/check_git_history.py
git diff --cached --stat
git commit -m "Prepare HingeVeil 0.1.11 source"
python3 scripts/check_git_history.py
git remote add origin https://github.com/OWNER/HingeVeil.git
git push -u origin main
```

If a `.git` directory or remote already exists, inspect it instead of repeating initialization. Stop on findings. Adding a new commit that deletes a secret does not remove the earlier commit. Revoke/rotate a real exposed credential first. This guide does not automatically rewrite history or force-push.

`check_git_history.py` applies limited patterns to the index and file/metadata contents of reachable commits across all refs, without printing matched values. `not_initialized` means no repository was checked, not that history is clean. Shallow clones are rejected. Unreachable objects, reflogs, remotes, Git LFS and all tag/signature information are not certified.

## 4. Repository settings after creation

- Verify the actual `Source checks` Actions run. A local pass does not establish a hosted CI pass. For private repositories, check Actions usage and billing controls.
- The supplied workflow only tests/builds on GitHub-hosted macOS. It uses read-only permissions, no persisted checkout credentials and a pinned external action SHA. It does not deploy, process payments or upload an app.
- Where available, protect `main` against force-pushes and require a PR and the `macOS source and build` check. Confirm available protections for the chosen GitHub plan.
- Check supported secret scanning and push protection. The included heuristic scanner is not a replacement.
- Read [rights/provenance review](RightsReview.md) before public visibility. MIT does not establish third-party code, artwork or trademark clearance.
- When making the repository public, enable private vulnerability reporting: currently Settings → Security and quality → Advanced Security → Private vulnerability reporting. Confirm the reporting entry on Security → Advisories. Do not advertise an operational reporting channel before it is enabled.
- Confirm the actual repository owner, no-reply commit address and desired public identity. The retained `com.bsl0707.hingeveil.preview` development identifier is not a credential. Source can retain it; choose a production binary identity separately.

## 5. Source publication is not a binary release

Public MIT source can be downloaded, copied, changed and used commercially, subject to retaining the required notices. Later making a repository private does not recall existing copies.

The ZIP is **source only**. It is not an installer, payment/license activation system or update server. Do not claim universal MacBook compatibility or completed Mission Control, sleep/lock, HDR, long-term memory/energy validation.

## Official references

Checked 2026-10-18: [GitHub licensing](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository), [private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository), [hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [pinned checkout v7.0.1](https://github.com/actions/checkout/tree/3d3c42e5aac5ba805825da76410c181273ba90b1).
