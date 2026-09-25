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
```

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
