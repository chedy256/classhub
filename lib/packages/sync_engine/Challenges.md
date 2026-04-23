# Challenges

## 1. Full clone vs. incremental sync

The first sync has no checkpoint, so the engine must download every file. Subsequent syncs use the GitHub compare API (`/compare/{old_sha}...{branch}`) to fetch only what changed.

The challenge is that the compare API returns a `404` when the stored commit SHA no longer exists — this happens on a force push, a branch recreation, or if the repo becomes private. The engine treats a `404` on compare as a recoverable error: it clears the checkpoint and triggers a full re-clone on the next `syncSource` call.

---

## 2. Error classification

Not all failures are equal. An offline device should not put a source in the same state as a corrupted sync.

Three cases needed different handling:

- **Network error (`SocketException`)** — set status to `idle`, return a friendly message. No re-clone needed; the source is fine.
- **Rate limit (`403`/`429`)** or transient HTTP error — set status to `error`. The next sync will trigger a full re-clone to get back to a clean state.
- **Unsupported URL / missing parser** — fail immediately with a clear message. No state is written.

---

## 3. GitHub tree truncation (and a known limitation)

The recursive tree API returns a `truncated: true` flag for repos above ~100k files or 7MB. There's no pagination — the data is simply incomplete. The engine throws a `StateError` immediately rather than silently syncing a partial tree.

The proper fix is to use the zipball endpoint for full clones, which downloads a complete archive regardless of size. This is the next planned improvement.

---

## Future improvements

- **Zipball full clone** — replace the recursive tree API call with the zipball endpoint to handle large repos and remove the truncation limitation
- **Path traversal protection** — `FileWriter` needs to validate that resolved file paths stay inside the target folder before writing; a malicious path like `../../etc/passwd` from a remote API could otherwise escape the sync directory
- **Parallel downloads** — `FileWriter` currently applies deltas sequentially; `Future.wait` with a concurrency limit would significantly reduce sync time for large changesets
- **GitHub token support** — the unauthenticated API allows 60 requests/hour; a token raises this to 5000 and enables private repo access
