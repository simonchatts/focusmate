{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  name = "focusmate-notify";
  buildInputs = with pkgs; [
    nushell        # script executor itself
    coreutils curl # script spawns "test" and "curl"
  ];
  src = ./.;
  installPhase = ''
    mkdir -p $out/bin
    cp *.nu $out/bin
  '';
}
