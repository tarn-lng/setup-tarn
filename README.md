# setup-tarn

Install a verified [Tarn](https://github.com/tarn-lng/tarn) toolchain on GitHub
Actions Linux runners (x86_64 and ARM64), with no container image.

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: tarn-lng/setup-tarn@v1
    with:
      version: 0.2.0   # or "latest"
  - run: tarn fetch && tarn verify
  - run: tarn test
```

## What it does

1. Downloads `tarn-<version>-linux-<arch>.tar.gz` and `SHA256SUMS` from the
   Tarn release, over HTTPS only.
2. Verifies the archive checksum, that it contains only the expected regular
   files, and that `tarn version` reports the requested version. These are
   the same checks as Tarn's `install.sh`.
3. Stores it in the runner tool cache and adds it to `PATH`. A later setup of
   the same version in the job reuses it.
4. Optionally caches the package store (`~/.tarn`, through `TARN_HOME`), keyed
   by the repository's `tarn.lock` files, so `tarn fetch` does not download
   locked packages again.

Native builds use the runner's `cc`, libc headers and libcurl. GitHub's Ubuntu
images include them.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `version` | `latest` | `X.Y.Z` (a leading `v` is accepted) or `latest` |
| `cache-packages` | `true` | Cache `~/.tarn` keyed by `tarn.lock` |
| `token` | `github.token` | Used only to resolve `latest` |

## Outputs

| Output | Meaning |
|---|---|
| `version` | The installed Tarn version |
| `path` | Directory containing `tarn` and `tarn-lsp` |

Pin a version for reproducible CI. `latest` follows new releases.

## License

MIT OR Apache-2.0, as Tarn.
