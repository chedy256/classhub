{
  description = "Flutter + Android development environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };
        androidSdk =
          (pkgs.androidenv.composeAndroidPackages {
            buildToolsVersions = [
              "34.0.0"
              "35.0.0"
              "36.0.0"
            ];
            platformVersions = [
              "34"
              "35"
              "36"
            ];
            includeNDK = true;
            ndkVersions = [ "28.2.13676358" ];
            includeCmake = true;
            cmakeVersions = [ "3.22.1" ];

            includeEmulator = false;
            includeSystemImages = false;
            # systemImageTypes = [ "google_apis_playstore" ];
            # abiVersions = [
            #   "x86_64"
            #   "arm64-v8a"
            # ]; # emulator needs x86_64
          }).androidsdk;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.flutter
            pkgs.jdk21
            pkgs.android-tools
            androidSdk
          ];
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
          JAVA_HOME = "${pkgs.jdk21}";
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/36.0.0/aapt2";
          shellHook = ''
            export SHELL="$(getent passwd "$USER" | cut -d: -f7)"
            exec "$SHELL"
          '';
        };
      }
    );
}
