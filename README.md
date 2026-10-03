# mise-backend-spinel

This is a [mise backend plugin](https://mise.jdx.dev/backend-plugin-development.html). A backend plugin tells mise how to find and install a type of tool. This plugin gets the source code of a Ruby command-line tool (CLI) from GitHub. Then it compiles the source into a native program with [Spinel](https://github.com/matz/spinel). Spinel is a compiler that changes Ruby code into C code and then into a native program.

You do not need a modified mise binary.

## What this plugin supports

The plugin compiles one Ruby file (the "entrypoint") into one program. Spinel supports only part of the Ruby language. Thus, many Ruby CLIs do not compile.

The plugin does not:

- install gems or other Ruby dependencies.
- copy data files or other assets into the install.
- fetch Git submodules.
- support Windows.

We test one tool: [`tobi/try`](https://github.com/tobi/try), at the commits in the example below. Other tools work only if Spinel can compile their entrypoint.

## Requirements

You must have:

- macOS or Linux.
- `git`.
- `make`, a C compiler, `curl`, and `tar`. Spinel needs these to build itself. Spinel also needs the C compiler when it compiles your tool.
- Network access to `github.com`, `api.github.com`, and `rubygems.org`.

When Spinel builds, its `make deps` step uses `curl` to download the Prism and RBS gems from rubygems.org. Then it uses `tar` to extract them.

## Example

Add this to your `mise.toml` file:

```toml
[plugins]
spinel = "https://github.com/nateberkopec/mise-backend-spinel"

[tools."spinel:tobi/try"]
version = "1.10.1"
entrypoint = "try.rb"
bin = "try"
tag_prefix = "v"
# The v1.10.1 tag is older than the Spinel fixes that try needs.
# This commit is the first compatible commit after that tag.
source_ref = "be566829856ca6bd22963e38a28ffb5efa24c7de"
spinel_ref = "1c84866b3acaaa6c568c3f239d3f4836f43c5bbb"
```

Then run:

```fish
mise install
mise x -- try --help
```

During `mise install`, the plugin does these steps:

1. It gets the `tobi/try` source at the `source_ref` commit.
2. It gets the Spinel source at the `spinel_ref` commit.
3. It builds Spinel in the temporary download directory of the tool.
4. It compiles `try.rb` into `bin/try` in the install directory.

The result is a native program. You do not need Ruby or Spinel to run it.

Mise usually deletes the download directory after an install. A new install then builds Spinel again. If mise keeps that directory, a later build can use files from the earlier build.

We tested this example on macOS arm64. The 399 specs of try passed with `SHELL=/bin/bash`. The two commits are the same commits that the [try native release workflow](https://github.com/nateberkopec/try/blob/main/.github/workflows/native-release.yml) uses.

## Options

Use the tool name `spinel:owner/repo`. The plugin gets the source from `https://github.com/owner/repo`.

| Option | Default | Meaning |
| --- | --- | --- |
| `entrypoint` | `main.rb` | The Ruby file to compile. It must be a relative path inside the repository. |
| `bin` | The repository name | The name of the program in `bin/`. It must be a file name, not a path. |
| `source_ref` | None | The full 40-character commit SHA of the tool source to build. |
| `tag_prefix` | None | Text before the version in each Git tag name. |
| `spinel_ref` | None | The full 40-character commit SHA of Spinel to build and use. |
| `spinel` | `spinel` | The Spinel program to use when `spinel_ref` is not set. |

A commit SHA is the 40-character hexadecimal ID of a Git commit. A Git tag is a name that points to a commit, such as `v1.0.0`.

## Versions and source commits

In mise, `version` is a label. Mise uses it to name the install.

If you do not set `source_ref`, the plugin builds the Git tag `<tag_prefix><version>`. For example, `tag_prefix = "v"` and `version = "1.0.0"` builds the tag `v1.0.0`. This name must be a valid Git tag name. The plugin uses `git check-ref-format` to examine it.

If you set `source_ref`, the plugin builds that commit. It does not use the tag. The version is then only a label. In the example, the label is `1.10.1`, but the plugin builds a commit that is newer than the `v1.10.1` tag. The CLI still shows `try v1.10.1`.

`mise ls-remote spinel:owner/repo` lists versions from Git tags. The plugin reads the first 100 tags that the GitHub API returns. If you set `tag_prefix`, the list shows only tags that start with the prefix, and it removes the prefix. For example, with `tag_prefix = "v"`, the tag `v1.10.1` shows as `1.10.1`.

## Important: mise keeps one build for each version label

Mise identifies an install by the tool name and the version label only. It does not look at the other options.

In this README, a "recipe" is the set of build options: `entrypoint`, `bin`, `source_ref`, `tag_prefix`, `spinel_ref`, and `spinel`. The recipe does not include `tag_prefix` when you set `source_ref`. It does not include `spinel` when you set `spinel_ref`.

If you change the recipe and keep the same version label, `mise install` does not build again. Mise sees that the label is already installed.

The plugin records the recipe in the install directory. When mise prepares the tool to run (for example, with `mise x`), the plugin compares the current recipe with the recorded recipe. If they are different, the command fails with this error:

```text
Spinel build options differ from the installed recipe; use a new version label and run mise install
```

The plugin does not add the old program to `PATH`, so `mise x` does not run the wrong build. The command also fails if the install has no recorded recipe. For example, an install from an older version of this plugin has no record.

To use a new recipe:

- Give each recipe a different version label. Then run `mise install`. Different labels can be installed at the same time.
- Set `source_ref` if you use a label that is not a Git tag, such as `1.10.1-be56682`. Without `source_ref`, the plugin uses the label to find the Git tag.

`mise install --force` builds again with the current recipe. It replaces the install for that label. It does not keep the old build next to the new build. Projects with the new recipe can use that build. A project that still uses the old recipe gets the error above.

## Which Spinel compiler the plugin uses

The plugin selects the compiler in this order:

1. If you set `spinel_ref`, the plugin builds Spinel at that commit and uses it. The plugin ignores `spinel`.
2. If you set `spinel`, the plugin uses that program. Use an absolute path or a command name on your `PATH`. The plugin runs the compiler in the source directory, so a relative path starts there.
3. If you set neither option, the plugin uses `spinel` from your `PATH`.

## Trust and reproducibility

This plugin downloads code from GitHub and builds it on your computer. The Spinel build runs `make`. The program that you install runs the code of the tool. Use only repositories that you trust.

The plugin does not verify checksums. Spinel does not verify the checksums of the gems that it downloads. A mise lockfile does not verify these builds. The builds are not byte-for-byte reproducible. The output can change with the C compiler and the operating system.

To make builds more stable:

- Set `source_ref` and `spinel_ref`.
- Pin the plugin to a known Git commit.

Installs and version lists need GitHub. Mise can add a configured GitHub token to API requests for version lists. GitHub limits requests that do not have a token. If GitHub is not available, or if it refuses the request, the command fails.

## Local development

The test project is in `test/fixture`. Its `mise.toml` loads the plugin from the repository root (`../..`). It uses the example above.

1. Go to the test project:

   ```fish
   cd test/fixture
   ```

2. Trust the test project configuration:

   ```fish
   mise trust
   ```

3. Make sure the version list contains `1.10.1`:

   ```fish
   mise ls-remote spinel:tobi/try
   ```

4. Build and install try:

   ```fish
   mise install
   ```

5. Run try:

   ```fish
   env SHELL=/bin/bash mise x -- try --help
   ```

   The output must contain `try v1.10.1`. The CI workflow sets `SHELL=/bin/bash` for this step.

6. To build again after you change the plugin, replace the install:

   ```fish
   mise install --force
   ```

7. Optional: test the recipe check. The `test/mismatch` project uses the same label (`1.10.1`) with a different `source_ref`:

   ```fish
   mise -C ../mismatch trust
   mise -C ../mismatch install
   mise -C ../mismatch x -- try --help
   ```

   The install does nothing, because `1.10.1` is already installed. The last command must fail with the error `Spinel build options differ from the installed recipe`.
