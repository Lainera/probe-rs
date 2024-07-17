{
  description = "Rust crate flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

  };

  outputs = { self, nixpkgs, flake-utils, crane, rust-overlay, ... }: flake-utils.lib.eachDefaultSystem
    (localSystem:
      let
        pkgs = import nixpkgs { inherit localSystem; overlays = [ (import rust-overlay) ]; };
        rustToolchain = pkgs.pkgsBuildHost.rust-bin.stable.latest.default;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        # There is a lot of random byte blob included in this codebase
        filter = path: type: true;
        common = {
          src = pkgs.lib.cleanSourceWith {
            src = pkgs.lib.cleanSource ./.;
            inherit filter;
            name = "sources";
          };
          strictDeps = true;
          buildInputs = [
            pkgs.systemd
          ];
          nativeBuildInputs = [
            pkgs.pkg-config
          ];
          doCheck = false;
        };
        crate = craneLib.buildPackage (common // {
          pname = "probe-rs";
          cargoExtraArgs = "-p probe-rs-tools --bin probe-rs";
          cargoArtifacts = craneLib.buildDepsOnly (common // {
            pname = "probe-rs";
          });
        });
      in
      {
        formatter = pkgs.nixpkgs-fmt;
        packages.default = crate;
        devShells.default = craneLib.devShell {
          checks = self.checks.${localSystem};
        };

        checks = { inherit crate; };
      }) // { nixosModules.default = import ./udev.nix; };
}
