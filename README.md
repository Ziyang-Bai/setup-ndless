# setup-ndless

A composite GitHub Action that installs the [Ndless](https://github.com/ndless-nspire/Ndless) SDK and ARM toolchain on Linux runners, exports the required environment variables, and caches the completed installation by Ndless commit.

## Usage

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4

      - name: Set up Ndless
        uses: Ziyang-Bai/setup-ndless@v1

      - name: Build project
        run: make
```

After the setup step, later steps receive:

- `NDLESS_HOME`: absolute path to `ndless-sdk`
- `NDLESS_SDK`: the same SDK path for projects that use this variable
- `PATH`: includes `arm-none-eabi-gcc`, `nspire-gcc`, `genzehn`, and `make-prg`

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `ndless-ref` | `master` | Ndless branch, tag, or full 40-character commit SHA. The action resolves branches and tags to an immutable commit before caching. |
| `install-dependencies` | `true` | Install build dependencies through `apt` or `dnf`. Set to `false` only on a prepared self-hosted runner. |
| `cache` | `true` | Restore and save the completed installation with `actions/cache`. |
| `jobs` | `0` | Parallel build jobs. `0` uses all processors reported by the runner. |

Example with a pinned Ndless revision:

```yaml
- uses: Ziyang-Bai/setup-ndless@v1
  with:
    ndless-ref: 9484d8da7c7a4dde9766138c2e42e1d1e3acfcd4
    jobs: 2
```

## Outputs

| Output | Description |
| --- | --- |
| `ndless-home` | Absolute path to the installed `ndless-sdk` directory. |
| `ndless-revision` | Full Ndless commit SHA selected by `ndless-ref`. |
| `cache-hit` | `true` when the completed installation came from the GitHub Actions cache. |

```yaml
- id: ndless
  uses: Ziyang-Bai/setup-ndless@v1
- run: echo "Using Ndless ${{ steps.ndless.outputs.ndless-revision }}"
```

## What the action does

1. Resolves the requested Ndless branch or tag to a full commit SHA.
2. Installs the Fedora or Debian/Ubuntu dependencies documented by the Ndless setup process.
3. Restores a commit-specific SDK cache when available.
4. Clones Ndless and its submodules on a cache miss.
5. Builds the ARM toolchain, including the GCC 14/libcody C++11 compatibility pass.
6. Builds the SDK and retries the known FreeType failure with the system-zlib configuration.
7. Verifies `arm-none-eabi-gcc`, `nspire-gcc`, `genzehn`, and `make-prg`, then exports the environment for later steps.

The first uncached build commonly takes 15–40 minutes. Subsequent runs using the same Ndless commit restore the completed installation.

## Supported runners

- GitHub-hosted Ubuntu runners
- Debian/Ubuntu self-hosted Linux runners
- Fedora self-hosted Linux runners

Windows and macOS runners are not supported directly. Windows projects should run the action on a Linux job rather than inside the Windows runner's WSL installation.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
