# tango-flake: use Tango from Nix(OS)

## Usage

### As a package

Use the overlay provided in case you only need, for example, cpptango:

```nix
{
  inputs.tango-controls.url = "git+https://gitlab.desy.de/cfel-sc-public/tango-flake";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  
  outputs = { self, flake-utils, tango-controls }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ tango-controls.overlays.default ];
          };
	    in
	      {
		    pkgs.stdenv.mkDerivation {
			  buildInputs = [ pkgs.cpptango-9_4 ];
			};
          });
}
```

### On NixOS

If you're using flakes with NixOS, add the tango flake to your inputs:

```nix
inputs.tango-controls.url = "git+https://gitlab.desy.de/cfel-sc-public/tango-flake";
```

and then use the modules provided:

```nix
{ tango-controls }:

{
  imports = [ tango-controls.nixosModules.tango-controls ];
  
  services.tango-controls.enable = true;
  services.mysql.package = pkgs.mariadb;
  services.mysql.enable = true;
}
```
