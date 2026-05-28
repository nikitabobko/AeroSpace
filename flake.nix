{
  description = ''
    Castrozan fork of AeroSpace exposing the prebuilt release zip as a flake
    package. The zip is built by the publish-castrozan-release workflow on
    every push to fix/** or feat/** branches and uploaded to a prerelease
    tagged castrozan-<sanitised-branch>.

    Consumers add this as a flake input and reference
    inputs.aerospace.packages.<system>.aerospace from their overlays.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem
      [
        "aarch64-darwin"
        "x86_64-darwin"
      ]
      (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          releaseTag = "castrozan-fix-tahoe-ax-prompt-loop";
          releaseZipUrl = "https://github.com/Castrozan/AeroSpace/releases/download/${releaseTag}/AeroSpace.app.zip";

          aerospace = pkgs.stdenv.mkDerivation {
            pname = "aerospace";
            version = releaseTag;

            src = pkgs.fetchurl {
              url = releaseZipUrl;
              sha256 = "sha256-kfPgLhyv4YMolyORtnGpqIR0qkiqc9znzj1VfKI9Ds8=";
            };

            nativeBuildInputs = [ pkgs.unzip ];

            sourceRoot = ".";

            unpackPhase = ''
              runHook preUnpack
              unzip "$src"
              runHook postUnpack
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/Applications $out/bin
              cp -R AeroSpace.app $out/Applications/
              cp aerospace $out/bin/
              runHook postInstall
            '';

            meta = {
              description = "Castrozan fork of AeroSpace - patches the macOS 26 Tahoe AX-prompt loop";
              homepage = "https://github.com/Castrozan/AeroSpace";
              license = pkgs.lib.licenses.mit;
              platforms = [
                "aarch64-darwin"
                "x86_64-darwin"
              ];
              mainProgram = "aerospace";
            };
          };
        in
        {
          packages = {
            aerospace = aerospace;
            default = aerospace;
          };
        }
      );
}
