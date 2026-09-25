{
  description = "The official Delta Linux binary distribution, packaged for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      releases = builtins.fromJSON (builtins.readFile ./releases.json);
      release = releases.nightly or null;
      hasRelease = system: release != null && release.systems ? ${system};

      runtimeLibsFor =
        pkgs: with pkgs; [
          stdenv.cc.cc.lib
          vulkan-loader
          libglvnd
          # Window-system libraries are also loaded dynamically.
          wayland
          libxkbcommon
          libx11
          libxcb
          libxcb-util
          libxcb-cursor
          libxcb-image
          libxcb-keysyms
          libxcb-render-util
          libxcb-wm
          libxcursor
          libxrandr
          libxi
          libxext
          libxrender
          libxfixes
          fontconfig
          freetype
          openssl
          zlib
          alsa-lib
        ];

      mkDelta =
        pkgs:
        let
          lib = pkgs.lib;
          asset = release.systems.${pkgs.stdenv.hostPlatform.system};
          runtimeLibraryPath = lib.makeLibraryPath (runtimeLibsFor pkgs);
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "delta";
          version = release.version;

          src = pkgs.fetchurl {
            url = "https://github.com/zed-industries/delta-nix/releases/download/${release.tag}/${asset.filename}";
            inherit (asset) hash;
          };

          nativeBuildInputs = with pkgs; [
            makeWrapper
            patchelf
          ];

          dontConfigure = true;
          dontBuild = true;
          dontStrip = true;
          # Generic fixup would shrink RPATHs needed by dlopen'd libraries.
          dontPatchELF = true;

          installPhase = ''
            runHook preInstall

            appDir="$out/opt/delta"
            mkdir -p "$appDir" "$out/bin" "$out/share/applications"
            cp -a . "$appDir/"
            chmod -R u+w "$appDir"

            # Nixpkgs' builds embed the matching xkeyboard-config store path;
            # the bundled builds expect /usr/share/X11/xkb.
            rm "$appDir/lib/libxkbcommon.so.0" "$appDir/lib/libxkbcommon-x11.so.0"

            # Keep the shipped libc++, libc++abi, and libunwind ahead of Nix libs.
            rpath="$appDir/lib:${runtimeLibraryPath}:\$ORIGIN/../lib:\$ORIGIN"
            find "$appDir" -type f \( -perm -0100 -o -name '*.so' -o -name '*.so.*' \) -print0 |
            while IFS= read -r -d "" elf; do
              if patchelf --print-rpath "$elf" >/dev/null 2>&1; then
                patchelf --set-rpath "$rpath" "$elf"
                if patchelf --print-interpreter "$elf" >/dev/null 2>&1; then
                  patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" "$elf"
                fi
              fi
            done

            # Transitive dlopen calls (including the Vulkan ICD chain) also
            # need LD_LIBRARY_PATH, not only the executable's RPATH.
            makeWrapper "$appDir/bin/delta" "$out/bin/delta" \
              --prefix LD_LIBRARY_PATH : "$appDir/lib:${runtimeLibraryPath}" \
              --set DELTA_UPDATE_EXPLANATION \
                "Delta is managed by Nix; update your flake input to install a newer release."

            cp -a "$appDir/share/icons" "$out/share/icons"
            for desktopFile in "$appDir"/share/applications/*.desktop; do
              substitute "$desktopFile" "$out/share/applications/$(basename "$desktopFile")" \
                --replace-fail "Exec=delta " "Exec=$out/bin/delta "
            done

            runHook postInstall
          '';

          doInstallCheck = true;
          installCheckPhase = ''
            runHook preInstallCheck

            ${pkgs.desktop-file-utils}/bin/desktop-file-validate \
              "$out/share/applications/"*.desktop
            grep -F "DELTA_UPDATE_EXPLANATION" "$out/bin/delta"
            find "$out/opt/delta" -type f \( -perm -0100 -o -name '*.so' -o -name '*.so.*' \) -print0 |
            while IFS= read -r -d "" elf; do
              if patchelf --print-rpath "$elf" >/dev/null 2>&1; then
                ${pkgs.glibc.bin}/bin/ldd "$elf"
              fi
            done | tee ldd.log
            if grep -q 'not found' ldd.log; then
              echo "unresolved shared-library dependencies remain" >&2
              exit 1
            fi
            grep -F "${lib.getLib pkgs.libxkbcommon}/lib/libxkbcommon.so.0" ldd.log
            grep -F "${lib.getLib pkgs.libxkbcommon}/lib/libxkbcommon-x11.so.0" ldd.log

            runHook postInstallCheck
          '';

          meta = {
            description = "Delta, the AI coding assistant";
            homepage = "https://delta.dev";
            license = lib.licenses.unfree;
            platforms = supportedSystems;
            mainProgram = "delta";
          };
        };
    in
    {
      packages = forAllSystems (
        system:
        nixpkgs.lib.optionalAttrs (hasRelease system) (
          let
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            delta = mkDelta pkgs;
          in
          {
            inherit delta;
            default = delta;
          }
        )
      );

      apps = forAllSystems (
        system:
        nixpkgs.lib.optionalAttrs (hasRelease system) (
          let
            delta = {
              type = "app";
              program = nixpkgs.lib.getExe self.packages.${system}.delta;
              meta.description = "Run Delta";
            };
          in
          {
            inherit delta;
            default = delta;
          }
        )
      );

      checks = forAllSystems (
        system:
        nixpkgs.lib.optionalAttrs (hasRelease system) {
          inherit (self.packages.${system}) delta;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              patchelf
              binutils
              file
              pax-utils
              strace
              gdb
            ];
          };
        }
      );
    };
}
