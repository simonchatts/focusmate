# focusmate-notify development environment
{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    nushell
    curl
    coreutils
  ];
}
