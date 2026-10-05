# Delta for Nix

Run the official [Delta](https://delta.dev) Linux binaries on NixOS.
This flake supports `x86_64-linux` and `aarch64-linux`.
Delta itself is proprietary; public downloads do not change its license.
See [Zed's terms](https://zed.dev/terms) and the
[Delta Early Access Agreement](https://delta.dev/early-access).

## Usage

```sh
nix run github:zed-industries/delta-nix
nix build github:zed-industries/delta-nix#delta
```

For a NixOS or Home Manager configuration, add this input to your flake:

```nix
inputs.delta.url = "github:zed-industries/delta-nix";
inputs.delta.inputs.nixpkgs.follows = "nixpkgs";
```

This shares the embedding flake's `nixpkgs` instead of using Delta's separate
pin. On NixOS, use the input that supplies your system's graphics stack,
including when installing Delta through standalone Home Manager.
Delta loads host drivers from `/run/opengl-driver`; an older glibc in Delta's
package can fail to load newer Mesa or LLVM libraries, causing
`GLIBC_… not found` and `No GPU adapters found` at startup.

Then add `inputs.delta.packages.${pkgs.stdenv.hostPlatform.system}.delta`
to `environment.systemPackages` (NixOS) or `home.packages` (Home Manager),
passing `inputs` into your modules as usual.

## Releases and updates

Update your input with `nix flake update delta`, then rebuild your
configuration. To select a particular release, pin the input to its tag:

```nix
inputs.delta.url = "github:zed-industries/delta-nix/v0.17.0";
```

A release tag pins both the package definition and the binary version.

For standalone builds from a local checkout, update this flake's `nixpkgs`
input with `nix flake update nixpkgs` and rebuild when upgrading the host
graphics stack. The `follows` declaration above handles this alignment when
Delta is embedded in your system flake.

The package exposes `delta` as the CLI. For paired-binary releases, the
desktop entry uses the wrapped CLI as `delta open %U` so deep-link URLs
reach the application, including for legacy entries that launched `delta-app`
directly. The separate app wrapper remains available; both wrappers receive
the Nix runtime library paths and have Delta's built-in updater disabled.
Older pinned releases with a single executable retain their original desktop
arguments (such as `cli open %U`).
