{
  description = "Tango is an Open Source solution for SCADA and DCS.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, poetry2nix }:
    let
      system = "x86_64-linux";
    in {
      packages.${system} =
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
          rec {
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
              version = "9.3.5";

              src = pkgs.fetchurl {
                url = "https://gitlab.com/api/v4/projects/24125890/packages/generic/TangoSourceDistribution/${version}/${pname}-${version}.tar.gz";
                sha256 = "1i59023gqm6sk000520y4kamfnfa8xqy9xwsnz5ch22nflgqn9px";
              };

              enableParallelBuilding = true;
              nativeBuildInputs = with pkgs; [ pkg-config jdk ];
              buildInputs = with pkgs; [ zlib omniorb_4_2 zeromq cppzmq ];

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

            default = tango-controls;
          };
    };
}
