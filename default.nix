{ pkgs ? import <nixpkgs> { } }:

# Override nushell to 0.38.0 until it propagates through nixpkgs
let nushell = pkgs.callPackage ./nushell-38 {
  inherit (pkgs.darwin.apple_sdk.frameworks) AppKit Security;
};
in

pkgs.stdenv.mkDerivation {
  name = "focusmate-notify";
  buildInputs = [ nushell pkgs.curl ];
  src = ./.;
  installPhase = ''
    mkdir -p $out/bin
    cp *.nu $out/bin
  '';
}
