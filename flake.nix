# focusmate-notify flake
{
  description = "Send notifications about imminent FocusMate sessions";

  outputs = { self, nixpkgs }:
    let
      name = "focusmate-notify";
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
        let pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        }; in f pkgs);
    in
    {
      # Overlay and default build artefacts
      overlay = final: prev: { "${name}" = final.callPackage ./. { }; };
      packages = forAllSystems (pkgs: { "${name}" = pkgs."${name}"; });
      defaultPackage = forAllSystems (pkgs: pkgs."${name}");

      # NixOS module
      nixosModule = import ./module.nix;

      # Development environment
      devShell = forAllSystems (pkgs: import ./shell.nix { inherit pkgs; });
    };
}
