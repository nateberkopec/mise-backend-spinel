# mise-backend-spinel

A [mise backend plugin](https://mise.jdx.dev/backend-plugin-development.html) that compiles Ruby CLIs from GitHub source with [Spinel](https://github.com/matz/spinel). No modified mise binary is needed. macOS and Linux only; building requires `git`, `make`, a C compiler and network access (Spinel's `make deps` fetches Prism and RBS).

```toml
[plugins]
spinel = "https://github.com/nateberkopec/mise-backend-spinel"

[tools."spinel:tobi/try"]
version = "1.10.1"
entrypoint = "try.rb"
bin = "try"
# The v1.10.1 tag predates the upstream Spinel fixes. This is the first
# compatible upstream commit; the CLI still reports try v1.10.1.
source_ref = "be566829856ca6bd22963e38a28ffb5efa24c7de"
spinel_ref = "1c84866b3acaaa6c568c3f239d3f4836f43c5bbb"
```

`mise install` builds Spinel at the pinned commit in the tool's temporary download directory, then compiles the pinned source into `bin/try`. The native binary needs neither Ruby nor Spinel at runtime. `mise x -- try --help` invokes it. A tool's `version` is its mise version label; when `source_ref` is specified, **it is the commit being built, not the corresponding release tag**. Both source commits above match [the native release workflow](https://github.com/nateberkopec/try/blob/main/.github/workflows/native-release.yml). Tested on macOS arm64 with try's 399 specs passing (`SHELL=/bin/bash`).

For other Ruby CLIs, use `spinel:owner/repo`; set `entrypoint` (default `main.rb`) and `bin` (default repo name). Without `source_ref`, the plugin checks out a Git tag matching `version`. Use `tag_prefix = "v"` to list and install tags such as `v1.0.0` as version `1.0.0`. Without `spinel_ref`, it uses `spinel` on `PATH`, or specify `spinel = "/path/to/spinel"`. `spinel_ref` takes precedence over `spinel`.

Version listing queries the most recent 100 GitHub tags. GitHub access and source compilation are not checksum-verified by a mise lockfile; pin `source_ref`, `spinel_ref`, and ideally the plugin's own Git revision for reproducible builds. As with any source compiler, only compile repositories you trust.

## Local development

```fish
mise plugin link spinel /path/to/mise-backend-spinel
mise ls-remote spinel:tobi/try
mise install spinel:tobi/try@1.10.1
```
