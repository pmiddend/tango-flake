{
  description = "Tango is an Open Source solution for SCADA and DCS.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      overlays.default = final: prev: {
        omniorb_4_2 = prev.stdenv.mkDerivation rec {
          pname = "omniorb";
          version = "4.2.5";

          src = prev.fetchurl {
            url = "mirror://sourceforge/project/omniorb/omniORB/omniORB-${version}/omniORB-${version}.tar.bz2";
            sha256 = "1fvkw3pn9i2312n4k3d4s7892m91jynl8g1v2z0j8k1gzfczjp7h";
          };

          nativeBuildInputs = [ prev.pkg-config ];
          # Python 3.11 is actually important here, the package breaks from 3.12 on.
          buildInputs = [ prev.python311 ];

          enableParallelBuilding = true;
          hardeningDisable = [ "format" ];
        };

        tango-idl-5 = final.callPackage ./tango-idl-5.nix { };
        tango-idl-6 = final.callPackage ./tango-idl-6.nix { };
        cpptango-9_4 = final.callPackage ./cpptango-9_4.nix { };
        cpptango-10_0 = final.callPackage ./cpptango-10_0.nix { };

        tango-controls-9_3 = pkgs.stdenv.mkDerivation rec {
          pname = "tango";
          version = "9.3.6";

          src = pkgs.fetchurl {
            url = "https://gitlab.com/api/v4/projects/24125890/packages/generic/TangoSourceDistribution/${version}/${pname}-${version}.tar.gz";
            hash = "sha256-1hN1QHh3hZfX1lQByMAmsc/96zuAH8gYsnRQynBOMko=";
          };

          enableParallelBuilding = true;
          nativeBuildInputs = with pkgs; [ jdk pkg-config ];
          buildInputs = with pkgs; [
            zlib
            final.omniorb_4_2
            zeromq
            cppzmq
          ];

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
        tango-controls-9_4 = pkgs.stdenv.mkDerivation rec {
          pname = "tango";
          version = "9.4.2";

          src = pkgs.fetchurl {
            url = "https://gitlab.com/api/v4/projects/24125890/packages/generic/TangoSourceDistribution/${version}/${pname}-${version}.tar.gz";
            hash = "sha256-3KQYBNd450gBRqJBa0SHXWXIADfpdNPeBLskXGTPqBY=";
          };

          enableParallelBuilding = true;
          nativeBuildInputs = with pkgs; [ cmake pkg-config ];
          buildInputs = with pkgs; [
            zlib
            final.omniorb_4_2
            zeromq
            cppzmq
            libjpeg_turbo
            mariadb-connector-c
            libsodium
            doxygen
            # without graphviz, the docs don't build
            graphviz
            systemd
          ];
          propagatedBuildInputs = with pkgs; [ final.omniorb_4_2 cppzmq zeromq libjpeg_turbo ];

          cmakeFlags = [
            "-DMySQL_LIBRARY_RELEASE=${pkgs.mariadb-connector-c}/lib/mariadb/libmariadb.so"
            "-DMySQL_INCLUDE_DIR=${pkgs.mariadb-connector-c.dev}/include/mariadb"
            "-DMySQL_EXECUTABLE=${pkgs.mariadb-connector-c}/bin/mariadb"
            "-DCMAKE_VERBOSE_MAKEFILE=TRUE"
            # Necessary because otherwise, cmake, on installation, will remove the runtime path from the executable,
            # thus we get "missing libmariadb.so".
            "-DCMAKE_SKIP_RPATH=ON"
            # Default is not to build access control
            "-DTSD_TAC=ON"
            "-DTSD_JAVA_PATH=${pkgs.openjdk11}"
          ];

          patches = [ ./fix-pc-file.patch ./sd_notify_cmake.patch ];

          postPatch = ''
            sed -i -e 's/MYSQL_VERSION_ID > 50000/1/' -e 's/mysql_get_client_version() >= 50013/1/' -e '/if (mysql_real_query(conn_pool\[con_nb\]\.db/i mysql_ping(conn_pool[con_nb].db);' -e 's/my_bool my_auto_reconnect=1;/my_bool my_auto_reconnect=1;WARN_STREAM << "client version: " << mysql_get_client_version() << std::endl;/' ./cppserver/database/DataBaseUtils.cpp
            sed -i -e 's#Requires: libzmq#Requires: libzmq cppzmq#' lib/cpp/tango.pc.cmake
          '';

          postInstall = ''
            mkdir -p $out/share/sql
            for fn in cppserver/database/*sql; do
              sed -e "s#^source #source $out/share/sql/#" "$fn" > $out/share/sql/$(basename "$fn")
            done
          '';
        };

      };

      lib.pytango-derivation-9_4 = final: self: super: {
        pytango = super.pytango.overrideAttrs (old: {
          buildInputs =
            let
              boostPython = self.boost.override {
                enablePython = true;
                python = self.python;
              };
            in
            [ final.tango-controls-9_4 boostPython final.omniorb_4_2 final.cppzmq final.zeromq self.setuptools final.libjpeg_turbo ];

          nativeBuildInputs = old.nativeBuildInputs ++ [ final.pkg-config ];

          dontWrapQtApps = true;
        });
      };

      lib.pytango-derivation-9_3 = final: self: super: {
        pytango = super.pytango.overrideAttrs (old: {
          buildInputs =
            let
              boostPython = self.boost.override {
                enablePython = true;
                python = self.python;
              };
            in
            [ final.tango-controls-9_3 boostPython final.omniorb_4_2 final.cppzmq final.zeromq self.setuptools ];

          nativeBuildInputs = old.nativeBuildInputs ++ [ final.pkg-config ];

          dontWrapQtApps = true;
        });
      };

      packages.${system} =
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs) cpptango-9_4 cpptango-10_0 tango-controls-9_4 tango-controls-9_3;
        };

      nixosModules.tango-controls =
        { pkgs, config, lib, ... }:
        {
          options.services.tango-controls = {
            enable = lib.mkEnableOption "enable Tango controls";

            enable-starter = lib.mkEnableOption "enable Tango Starter service";

            database = with pkgs.lib; {
              name = mkOption {
                type = types.str;
                default = "tango";
                description = lib.mdDoc "Database name.";
              };

              user = mkOption {
                type = types.str;
                default = "tango";
                description = lib.mdDoc "Database user.";
              };

              passwordFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                example = "/run/keys/tango-dbpassword";
                description = lib.mdDoc ''
                  A file containing the password corresponding to
                  {option}`database.user`.
                '';
              };
            };
          };

          config = lib.mkIf config.services.tango-controls.enable {
            nixpkgs.overlays = [ self.overlay ];

            services.mysql = {
              # Taken from the gitea.nix module
              ensureDatabases = [ config.services.tango-controls.database.name ];
              ensureUsers = [
                {
                  name = config.services.tango-controls.database.user;
                  ensurePermissions = { "${config.services.tango-controls.database.name}.*" = "ALL PRIVILEGES"; };
                }
              ];
            };

            environment.systemPackages = [ pkgs.tango-controls-9_4 ];
            environment.variables = {
              TANGO_HOST = "localhost:10000";
            };

            # taken from https://xeiaso.net/blog/nix-flakes-1-2022-02-21
            users.groups.tango = { };

            users.users.tango = {
              name = config.services.tango-controls.database.user;
              group = "tango";
              isSystemUser = true;
            };


            # see https://tango-controls.readthedocs.io/en/latest/tutorials-and-howtos/how-tos/how-to-integrate-with-systemd.html
            systemd.services.tango-db = {
              description = "Tango Controls database server";
              requires = [ "mysql.service" ];
              after = [ "network.target" "mysql.service" ];

              serviceConfig = {
                Type = "notify";
                User = config.services.tango-controls.database.user;
                Environment = [ "TANGO_HOST=localhost:10000" ];
                ExecStart =
                  # I've tried ${hostName} instead of 0.0.0.0 but this fails very weirdly
                  "${pkgs.tango-controls-9_4}/bin/Databaseds 2 -ORBendPoint giop:tcp:0.0.0.0:10000";
                # For some reason, this doesn't work. Gives "no such file or direcotry" while spawning the
                # ExecStartPre script.
                # StandardOutput = "file:/var/log/tango-db/stdout.txt";
                # StandardError = "file:/var/log/tango-db/stderr.txt";
                # LogsDirectory = "tango-db";
              };

              # postStart = ''
              #   count=0
              #   while ! grep --silent "Ready to accept request" /var/log/tango-db/stdout.txt;
              #   do
              #     if [ $count -eq 30 ]
              #     then
              #         echo "Tried 30 times, giving up..."
              #         exit 1
              #     fi
              #     echo "Waiting for start";
              #     count=$((count++))
              #     sleep 1s;
              #   done
              # '';


              # This is taken from the zoneminder.nix module
              preStart = ''
                MY_TANGO_DB_ALREADY_THERE=$(${config.services.mysql.package}/bin/mysql -u ${config.services.tango-controls.database.user} --skip-column-names <<< "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA LIKE '${config.services.tango-controls.database.name}' AND TABLE_NAME = 'device'")

                if [ "$MY_TANGO_DB_ALREADY_THERE" = "0" ]; then
                  echo "Creating Tango tables"
                  # The DB has been created by Nix on MySQL service creation already, so leave that statement
                  # out of the SQL migration thing using crude "sed" logic
                  sed '/CREATE DATABASE/d' ${pkgs.tango-controls-9_4}/share/sql/create_db.sql | ${config.services.mysql.package}/bin/mysql -u ${config.services.tango-controls.database.user} ${config.services.tango-controls.database.name}
                else
                  echo "Tango tables already there, skipping creation"
                fi
              '';
            };

            systemd.services.tango-accesscontrol = {
              description = "TangoAccessControl device server";
              requires = [ "tango-db.service" ];
              after = [ "tango-db.service" ];

              # unitConfig = {
              #   StopWhenUnneeded = true;
              # };

              serviceConfig = {
                User = config.services.tango-controls.database.user;
                Environment = [ "TANGO_HOST=localhost:10000" ];
                ExecStartPre = "${pkgs.coreutils}/bin/sleep 3s";
                ExecStart = "${pkgs.tango-controls-9_4}/bin/TangoAccessControl 1";
              };
            };

            systemd.services.tango-starter = lib.mkIf config.services.tango-controls.enable-starter {
              description = "Starter device server";
              after = [ "tango.target" ];
              requires = [ "tango.target" ];

              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                # Restart = "always";
                # RestartSec = 10;
                Type = "simple";
                User = config.services.tango-controls.database.user;
                Environment = [ "TANGO_HOST=localhost:10000" ];
                ExecStart = "${pkgs.tango-controls-9_4}/bin/Starter ${config.networking.hostName}";
              };
              preStart =
                let hostName = config.networking.hostName;
                in ''
                  echo "Adding starter device for host name ${hostName}"
                  ${pkgs.tango-controls-9_4}/bin/tango_admin --add-server Starter/${hostName} Starter tango/admin/${hostName}
                  echo "Starting device server"
                '';
            };

            systemd.targets.tango = {
              description = "Tango development environment target";
              # requires = [ "tango-db.service" "tango-starter.service" "tango-accesscontrol.timer" ];
              requires = [ "tango-db.service" "tango-accesscontrol.service" ];
              after = [ "tango-db.service" "tango-accesscontrol.service" ];
              wantedBy = [ "multi-user.target" ];
            };

            systemd.services.tango-test = {
              after = [ "tango.target" ];

              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                User = config.services.tango-controls.database.user;
                Environment = [ "TANGO_HOST=localhost:10000" ];
                ExecStart = "${pkgs.tango-controls-9_4}/bin/TangoTest test";
                # necessary because the Databaseds takes a few seconds to "really" be online
                ExecStartPre = "${pkgs.coreutils}/bin/sleep 3s";
              };
            };
          };
        };

      checks.${system}.vmTest =
        pkgs.nixosTest
          {
            name = "wait-for-service-start";

            nodes = {
              client = { pkgs, ... }: {
                imports = [ self.nixosModules.tango-controls ];

                services.mysql.enable = true;
                services.mysql.package = pkgs.mariadb;
                services.tango-controls.enable = true;
                services.tango-controls.enable-starter = true;
              };
            };

            testScript =
              ''
                start_all()
                client.wait_for_unit("tango-accesscontrol")
                client.wait_for_unit("tango-db")
                client.wait_for_unit("tango-starter")

                client.succeed("tango_admin --ping-database")
                client.succeed("tango_admin --check-device sys/tg_test/1")
              '';
          };
    };
}
