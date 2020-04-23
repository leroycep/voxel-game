The `shell.nix` contains zig, but don't use this zig to compile the game unless
you are on NixOS. If you compile the game using the zig in the `shell.nix`, it
will fail to create the openEGL context.
