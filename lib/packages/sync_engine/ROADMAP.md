# Roadmap

## Done

- GitHub parser — supports `https`, `github.com/`, `git@` and branch URLs
- GitHub syncer — full clone (recursive tree API) and incremental diff (compare API)
- `SourceStore` — reads/writes `source.json`, tracks sync state and checkpoint
- Full test coverage for all components

## Up next

- **FileWriter** — applies deltas to disk with path traversal protection
- **Zipball full clone** — use GitHub's zipball endpoint instead of the tree API for faster initial clones on large repos
- **Progress reporting** — expose per-file progress during sync so the UI can show a progress indicator

## Planned

- **Google Drive support** — parser and syncer for public Drive folders
- **Google Classroom support** — parser and syncer using the Classroom API
- **Parallel downloads** — download multiple files concurrently to reduce sync time
- **GitHub token support** — allow passing a personal access token for private repos and higher rate limits
- **Selective sync** — allow excluding files or folders by pattern
