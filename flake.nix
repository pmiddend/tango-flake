{
  description = "Tango is an Open Source solution for SCADA and DCS.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.poetry2nix = {
    url = "github:nix-community/poetry2nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, poetry2nix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      overlay = final: prev: {
        omniorb_4_2 = with pkgs; stdenv.mkDerivation rec {
          pname = "omniorb";
          version = "4.2.5";

          src = fetchurl {
            url = "mirror://sourceforge/project/omniorb/omniORB/omniORB-${version}/omniORB-${version}.tar.bz2";
            sha256 = "1fvkw3pn9i2312n4k3d4s7892m91jynl8g1v2z0j8k1gzfczjp7h";
          };

          nativeBuildInputs = [ pkg-config ];
          buildInputs = [ python3 ];

          enableParallelBuilding = true;
          hardeningDisable = [ "format" ];
        };
        tango-controls = pkgs.stdenv.mkDerivation rec {
          pname = "tango";
          version = "9.3.6";

          src = pkgs.fetchurl {
            url = "https://gitlab.com/api/v4/projects/24125890/packages/generic/TangoSourceDistribution/${version}/${pname}-${version}.tar.gz";
            sha256 = "sha256-1hN1QHh3hZfX1lQByMAmsc/96zuAH8gYsnRQynBOMko=";
          };

          enableParallelBuilding = true;
          nativeBuildInputs = with pkgs; [ pkg-config jdk ];
          buildInputs = with pkgs; [ zlib final.omniorb_4_2 zeromq cppzmq ];

          configureFlags = with pkgs; [
            "--enable-java=yes"
            "--enable-dbserver=yes"
            "--with-java=${openjdk8}/bin/java"
            "--with-mysqlclient-lib=${mariadb-connector-c}/lib/mariadb/"
            "--with-mysqlclient-include=${mariadb-connector-c.dev}/include/mariadb"
          ];

          postPatch = ''
            sed -i -e 's/MYSQL_VERSION_ID > 50000/1/' -e 's/mysql_get_client_version() >= 50013/1/' -e '/if (mysql_real_query(conn_pool\[con_nb\]\.db/i mysql_ping(conn_pool[con_nb].db);' -e 's/my_bool my_auto_reconnect=1;/my_bool my_auto_reconnect=1;WARN_STREAM << "client version: " << mysql_get_client_version() << std::endl;/' ./cppserver/database/DataBaseUtils.cpp
          '';

          postInstall = ''
            mkdir -p $out/share/sql
            for fn in cppserver/database/*sql; do
              sed -e "s#^source #source $out/share/sql/#" "$fn" > $out/share/sql/$(basename "$fn")
            done
          '';
        };
      };

      pytango-derivation = final: self: super: {
        pytango = super.pytango.overrideAttrs (old: {
          buildInputs =
            let
              boostPython = self.boost.override {
                enablePython = true;
                python = self.python;
              };
            in
            [ final.tango-controls boostPython final.omniorb_4_2 final.cppzmq final.zeromq self.setuptools ];

          nativeBuildInputs = old.nativeBuildInputs ++ [ final.pkg-config ];

          dontWrapQtApps = true;
        });
      };

      packages.${system} =
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlay ];
          };
        in
        {
          tango-controls = pkgs.tango-controls;
          default = pkgs.tango-controls;
        };
    };
}
