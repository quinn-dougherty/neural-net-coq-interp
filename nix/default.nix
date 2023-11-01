{ self, inputs, ... }: {
  perSystem = { config, self', inputs', pkgs, system, ... }:
    let
      doom-emacs = with inputs;
        import ./emacs.nix { inherit pkgs nix-doom-emacs; };
      vscodium = import ./codium.nix { inherit pkgs; };
      shell = { text-editor ? [ ] }:
        import ./shell.nix { inherit pkgs text-editor; };
    in {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      devShells = {
        coq-no-ui = shell { };
        emacs = shell { text-editor = [ doom-emacs ]; };
        codium = shell { text-editor = [ vscodium ]; };
        coq = shell { text-editor = [ doom-emacs vscodium ]; };
      };
      packages = {
        coq-nn-dune = pkgs.stdenv.mkDerivation {
        name = "coq-neural-net-interp-compile-dune";
        buildInputs = (shell { }).buildInputs;
        src = ./..;
        buildPhase = ''
          dune build
        '';
        installPhase = ''
          mkdir -p $out
          cp -r _build/* $out
        '';
        };
        coq-nn = pkgs.stdenv.mkDerivation {
          name = "coq-neural-net-interp-compile-make";
          buildInputs = (shell {}).buildInputs;
          src = ./..;
          buildPhase = "make";
          installPhase = ''
            mkdir -p $out
            cp -r theories/* $out
          '';
        };
      };

    };
}
