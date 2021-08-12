{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  name = "focusmate-notify";
  buildInputs = with pkgs; [ nushell curl ];
  src = ./.;
  installPhase = ''
    mkdir -p $out/bin
    cp *.nu $out/bin
  '';
}
