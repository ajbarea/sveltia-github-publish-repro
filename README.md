# sveltia-github-publish-repro

Minimal reproduction for Sveltia CMS: pressing Publish on GitHub while a required status check is still running.

## What is in this repository

- `admin/index.html` loads Sveltia CMS 0.248.0, which includes the fix. The results below were recorded with 0.241.0.
- `admin/config.yml` uses the GitHub backend, `publish_mode: preview` and `squash_merges: true`.
- `.github/workflows/check.yml` runs a job named `check` (`sleep 300`) on every pull request.
- A ruleset on `main` requires `check` and has no bypass actors. Auto-merge is allowed in the repository settings.

## Reproduce in the CMS

1. Clone the repository, run `python3 -m http.server 8000` at its root, and open `http://localhost:8000/admin/`.
2. Choose **Sign In Using Access Token**, with a token that can write contents and pull requests here.
3. Open **Posts > Hello**, change the title, and press **Save**. Sveltia opens a draft pull request from `cms/posts/hello`.
4. Within five minutes, while `check` is still running, press **Publish** and confirm.

Result on 2026-10-17 (pull request #3, first attempt): the toast reads "Couldn't publish the entry. Please try again." The console shows a 405 from `PUT /repos/ajbarea/sveltia-github-publish-repro/pulls/3/merge`. The pull request is left marked ready, labelled `sveltia-cms/pending_publish`, with no auto-merge. The editor has to return after the check finishes and press Publish again.

Second attempt, same pull request: with the ruleset disabled and classic branch protection that requires `check` but does not apply to administrators (`enforce_admins: false`), the same steps as a repository admin merged #3 at 20:25:12Z. `check` had started at 20:25:05Z and was still in progress.

## Reproduce with the API

`./repro.sh` (needs `gh` signed in with write access) sends the request `publish()` sends, then the proposed alternative. Output on 2026-10-17:

```
PR #1, head d2a704bf610ce8a9d138107bfb6e295d84c20171
== 1. What publish() sends today, while the required check is still running
HTTP/2.0 405 Method Not Allowed
{"message":"Repository rule violations found\n\nRequired status check \"check\" is in progress.\n\n","documentation_url":"https://docs.github.com/rest/pulls/pulls#merge-a-pull-request","status":"405"}
== 2. Proposed: enablePullRequestAutoMerge, pinned with expectedHeadOid
{"enabledAt":"2026-10-17T20:15:53Z","mergeMethod":"SQUASH"}
```

GitHub merged #1 at 20:21:03Z, once `check` passed, as the user who enabled auto-merge.
