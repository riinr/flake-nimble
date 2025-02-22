{
  inputs.nimrevs.url = "github:riinr/flake-crown?dir=pkgsRev";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";

  outputs = inputs:
  let mkPkg  = nixpkgsVersion:
    let
      pkgs   = nixpkgsVersion.legacyPackages.x86_64-linux;
      toFlag = builtins.map (src: "-p:${src}");
      deps   = inputs.nimrevs.lib.srcs {
        inherit pkgs;
        nimPkgs = [ "cligen" ];
      };
    in
    pkgs.nimPackages.buildNimPackage {
      nimBinOnly  = true;
      nimFlags    = toFlag deps;
      pname       = "cligen-example";
      src         = ./.;
      version     = "0.1.0";
      meta.ref     = "master";
      meta.version = "0.1.0";
      meta.name    = "cligen-example";
      meta.desc    = "Example of cligen";
    };
  in
  {
    packages.x86_64-linux.default = mkPkg inputs.nixpkgs;
  };
}
