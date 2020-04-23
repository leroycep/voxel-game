let
  pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  buildInputs = [
    pkgs.zig
    pkgs.SDL2
    pkgs.freetype
    pkgs.epoxy
  ];
}
