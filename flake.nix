{
  description = "Inform 7: a literate programming system for interactive fiction";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    inweb-src = {
      url = "github:ganelson/inweb";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, inweb-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # we use clangStdenv because Graham Nelson recommends clang
        # and has hardcoded it in a bunch of different meta build scripts

        inweb = pkgs.clangStdenv.mkDerivation {
          pname = "inweb";
          version = "9.0-beta";
          src = pkgs.fetchFromGitHub {
            owner = "ganelson";
            repo = "inweb";
            rev = "147001c346e6959a1f4801a6af3c3f522dd7db52";
            sha256 = "sha256-9kJT8YO3mDCfZe1ZlstC7tlBeY5KuDL4TVXSAQ8V3Zg=";
          };

          patches = [ ./inweb-help-segfault.patch ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontStrip = true;

          buildPhase = ''
            cd ..
            mv source inweb
            cp -f inweb/Materials/platforms/linux.mk inweb/platform-settings.mk
            cp -f inweb/Materials/platforms/inweb-on-linux.mk inweb/inweb.mk
            make -f inweb/inweb.mk initial CC="$CC"
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp inweb/Tangled/inweb $out/bin/
            mkdir -p $out/share/inweb
            cp -r inweb/foundation-module $out/share/inweb/
            cp -r inweb/literate-module $out/share/inweb/
            cp -r inweb/Materials $out/share/inweb/
            mkdir -p $out/share/inweb/Tangled

            # fuck my unconventional Nix compiler bootstrapping chungus life
            cat > $out/share/inweb/Tangled/inweb <<EOF
            #!/bin/sh
            exec $out/bin/inweb "\$@"
            EOF

            chmod +x $out/share/inweb/Tangled/inweb
            cp inweb/platform-settings.mk $out/share/inweb/platform-settings.mk
          '';

          # adding the -at flag to the inweb binary
          # works better than the INWEB_PATH environment variable
          # because it has higher precedence;
          # see Chapter 3.3 https://ganelson.github.io/inweb/foundation-module/3-pth.html
          postFixup = ''
            wrapProgram $out/bin/inweb \
              --append-flags "-at $out/share/inweb"
          '';

          meta = with pkgs.lib; {
            description = "A modern literate programming system";
            homepage = "https://ganelson.github.io/inweb/";
            license = licenses.artistic2;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        intest = pkgs.clangStdenv.mkDerivation {
          pname = "intest";
          version = "2.2.0-beta";

          src = pkgs.fetchFromGitHub {
            owner = "ganelson";
            repo = "intest";
            rev = "6f493eae2cd568c7883283642dc4dde899fd9aed";
            sha256 = "sha256-3qLt/BRXn9GJfEXOIiC+XsgLF+YdXSMisyhlcRgHrzE=";
          };

          nativeBuildInputs = [ inweb ];

          buildPhase = ''
            # Create the directory structure the makefile expects
            cd ..
            mv source intest

            # Create inweb directory structure (just for Materials, not the binary)
            cp -r ${inweb}/share/inweb inweb
            chmod -R u+w inweb  # Make it writable

            # Copy platform settings
            cp inweb/Materials/platforms/linux.mk inweb/platform-settings.mk

            # Set INWEB_PATH for the build
            export INWEB_PATH=${inweb}/share/inweb

            # Patch first.sh to use inweb from PATH instead of relative path
            sed -i 's|inweb/Tangled/inweb|${inweb}/bin/inweb|g' intest/scripts/first.sh

            # Run first.sh from parent directory
            bash -x intest/scripts/first.sh
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp intest/Tangled/intest $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "A testing tool for command-line programs";
            homepage = "https://ganelson.github.io/intest/";
            license = licenses.artistic2;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        inform = pkgs.clangStdenv.mkDerivation {
          pname = "inform7";
          version = "10.2.0";
          src = pkgs.fetchFromGitHub {
            owner = "ganelson";
            repo = "inform";
            rev = "2c77a75572f94064b2ad946e69f22c542cdf1992";
            sha256 = "sha256-zacN4t/pH743Y0AomnGx432Whk1wv/3TTVGB3osKGQI=";
          };

          nativeBuildInputs = [ pkgs.makeWrapper inweb intest ];

          buildPhase = ''
            cd ..
            mv source inform
            cp -r ${inweb}/share/inweb inweb
            cd inform
            bash scripts/first.sh
          '';

          installPhase = ''
            mkdir -p $out/bin
            for tool in inbuild inform7 inter inblorb inpolicy; do
              cp $tool/Tangled/$tool $out/bin/
            done

            mkdir -p $out/share/inform7
            cp -r inform7/Internal $out/share/inform7/
          '';

          postFixup = ''
            wrapProgram $out/bin/inform7 \
              --set INFORM7_PATH $out/share/inform7 \
              --set INWEB_PATH ${inweb}/share/inweb

            wrapProgram $out/bin/inbuild \
              --set INBUILD_PATH $out \
              --set INWEB_PATH ${inweb}/share/inweb

            wrapProgram $out/bin/inter \
              --set INWEB_PATH ${inweb}/share/inweb

            wrapProgram $out/bin/inblorb \
              --set INWEB_PATH ${inweb}/share/inweb

            wrapProgram $out/bin/inpolicy \
              --set INWEB_PATH ${inweb}/share/inweb
          '';

          meta = with pkgs.lib; {
            description = "Inform 7 compiler for interactive fiction";
            homepage = "https://ganelson.github.io/inform/";
            license = licenses.artistic2;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

      in {
        packages = {
          inherit inweb intest inform;
          default = inform;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ inweb intest inform ];
        };
      }
    );
}
