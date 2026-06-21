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

        informSrc = pkgs.fetchFromGitHub {
          owner = "ganelson";
          repo = "inform";
          rev = "2c77a75572f94064b2ad946e69f22c542cdf1992";
          sha256 = "sha256-zacN4t/pH743Y0AomnGx432Whk1wv/3TTVGB3osKGQI=";
        };

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

        informUnwrapped = pkgs.clangStdenv.mkDerivation {
          pname = "inform7";
          version = "10.2.0";
          src = informSrc;

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

        glulxe = pkgs.stdenv.mkDerivation {
          pname = "glulxe-cheapglk";
          version = "0.6.1";
          src = informSrc;

          buildPhase = ''
            runHook preBuild

            cd inform6/Tests/Assistants/dumb-glulx/cheapglk
            make CC="$CC" OPTIONS="$CFLAGS"

            cd ../glulxe
            make CC="$CC" \
              GLKINCLUDEDIR=../cheapglk \
              GLKLIBDIR=../cheapglk \
              GLKMAKEFILE=Make.cheapglk \
              OPTIONS="$CFLAGS -Wno-unused -DOS_UNIX -DUNIX_RAND_GETRANDOM"

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            cp glulxe $out/bin/

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Glulx VM interpreter linked with CheapGlk";
            homepage = "https://eblong.com/zarf/glulx/";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        remglk = pkgs.stdenv.mkDerivation {
          pname = "remglk";
          version = "0.3.2";

          src = pkgs.fetchFromGitHub {
            owner = "erkyrath";
            repo = "remglk";
            rev = "remglk-0.3.2";
            sha256 = "1b2z8ryz4k1hw33z44spvbymngyhx8g1kdhbwpg6ifnrn56aafgs";
          };

          buildPhase = ''
            runHook preBuild

            make CC="$CC" OPTIONS="$CFLAGS"

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib $out/include/remglk
            cp libremglk.a $out/lib/
            cp Make.remglk glk.h glkstart.h gi_blorb.h gi_debug.h gi_dispa.h remglk.h $out/include/remglk/

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Remote-procedure-call Glk library with JSON input and output";
            homepage = "https://eblong.com/zarf/glk/remglk/";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        glulxe-remglk = pkgs.stdenv.mkDerivation {
          pname = "glulxe-remglk";
          version = "0.6.1";
          src = informSrc;

          buildPhase = ''
            runHook preBuild

            cd inform6/Tests/Assistants/dumb-glulx/glulxe
            make CC="$CC" \
              GLKINCLUDEDIR=${remglk}/include/remglk \
              GLKLIBDIR=${remglk}/lib \
              GLKMAKEFILE=Make.remglk \
              OPTIONS="$CFLAGS -Wno-unused -DOS_UNIX -DUNIX_RAND_GETRANDOM"

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            cp glulxe $out/bin/glulxe-remglk

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Glulx VM interpreter linked with RemGlk JSON backend";
            homepage = "https://eblong.com/zarf/glulx/";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        inform = pkgs.runCommand "inform7-10.2.0" {
          nativeBuildInputs = [ pkgs.makeWrapper ];
        } ''
          mkdir -p $out/bin $out/share
          ln -s ${informUnwrapped}/share/inform7 $out/share/inform7

          for tool in inbuild inter inblorb inpolicy; do
            ln -s ${informUnwrapped}/bin/$tool $out/bin/$tool
          done

          cat > $out/bin/inform7 <<EOF
          #!${pkgs.runtimeShell}
          set -e

          internal_src="${informUnwrapped}/share/inform7/Internal"
          cache_base="\''${INFORM7_CACHE_HOME:-\''${XDG_CACHE_HOME:-\''${HOME:-/tmp}/.cache}/inform7-nix}"
          internal_cache="\$cache_base/10.2.0/Internal"
          marker="\$internal_cache/.nix-store-source"

          if [ ! -d "\$internal_cache" ] || [ "\$(cat "\$marker" 2>/dev/null || true)" != "\$internal_src" ]; then
            tmp="\$internal_cache.tmp.\$\$"
            rm -rf "\$tmp"
            mkdir -p "\$(dirname "\$internal_cache")"
            cp -R "\$internal_src" "\$tmp"
            chmod -R u+w "\$tmp"
            printf '%s\n' "\$internal_src" > "\$tmp/.nix-store-source"
            rm -rf "\$internal_cache"
            mv "\$tmp" "\$internal_cache"
          fi

          export INFORM7_PATH="\$internal_cache"
          export INWEB_PATH="${inweb}/share/inweb"
          exec "${informUnwrapped}/bin/inform7" -internal "\$internal_cache" "\$@"
          EOF
          chmod +x $out/bin/inform7

          cat > $out/bin/i7-check <<EOF
          #!${pkgs.runtimeShell}
          set -e
          if [ "\$#" -ne 1 ]; then
            echo "usage: i7-check SOURCE.ni" >&2
            exit 64
          fi
          tmp="\$(mktemp -d)"
          trap 'rm -rf "\$tmp"' EXIT
          "$out/bin/inform7" -source "\$1" -format=Inform6/16 -o "\$tmp/story.i6" -no-progress -no-index -no-problems
          EOF
          chmod +x $out/bin/i7-check

          cat > $out/bin/i7-build <<EOF
          #!${pkgs.runtimeShell}
          set -e
          format=zcode
          if [ "\''${1:-}" = "--glulx" ]; then
            format=glulx
            shift
          elif [ "\''${1:-}" = "--zcode" ]; then
            shift
          fi
          if [ "\$#" -lt 1 ] || [ "\$#" -gt 2 ]; then
            echo "usage: i7-build [--zcode|--glulx] SOURCE.ni [OUTPUT]" >&2
            exit 64
          fi
          source="\$1"
          case "\$format" in
            zcode)
              i7_format=Inform6/16
              i6_switches=-wv8
              output="\''${2:-\''${source%.*}.z8}"
              ;;
            glulx)
              i7_format=Inform6/32
              i6_switches=-wG
              output="\''${2:-\''${source%.*}.ulx}"
              ;;
          esac
          tmp="\$(mktemp -d)"
          trap 'rm -rf "\$tmp"' EXIT
          "$out/bin/inform7" -source "\$source" -format="\$i7_format" -o "\$tmp/story.i6" -no-progress -no-index -no-problems
          ${pkgs.inform6}/bin/inform "\$i6_switches" '\$MAX_STATIC_DATA=500000' '\$MAX_ZCODE_SIZE=524288' "\$tmp/story.i6" "\$output"
          echo "Wrote \$output"
          EOF
          chmod +x $out/bin/i7-build

          cat > $out/bin/i7-play <<EOF
          #!${pkgs.runtimeShell}
          set -e
          if [ "\''${1:-}" = "--remglk" ]; then
            shift
            exec ${glulxe-remglk}/bin/glulxe-remglk "\$@"
          fi
          if [ "\$#" -ne 1 ]; then
            echo "usage: i7-play [--remglk] STORY.z8|STORY.ulx" >&2
            exit 64
          fi
          case "\$1" in
            *.ulx|*.ULX)
              exec ${glulxe}/bin/glulxe "\$1"
              ;;
            *)
              exec ${pkgs.frotz}/bin/frotz -p -q "\$1"
              ;;
          esac
          EOF
          chmod +x $out/bin/i7-play

          cat > $out/bin/i7-play-remglk <<EOF
          #!${pkgs.runtimeShell}
          set -e
          if [ "\$#" -lt 1 ]; then
            echo "usage: i7-play-remglk [REMGLK/GLULXE OPTIONS] STORY.ulx|STORY.gblorb" >&2
            exit 64
          fi
          exec ${glulxe-remglk}/bin/glulxe-remglk "\$@"
          EOF
          chmod +x $out/bin/i7-play-remglk

          cat > $out/bin/i7-release-web <<EOF
          #!${pkgs.runtimeShell}
          set -e

          format=glulx
          force=0
          while [ "\$#" -gt 0 ]; do
            case "\$1" in
              --glulx)
                format=glulx
                shift
                ;;
              --zcode)
                format=zcode
                shift
                ;;
              --force)
                force=1
                shift
                ;;
              --)
                shift
                break
                ;;
              -*)
                echo "usage: i7-release-web [--glulx|--zcode] [--force] SOURCE.ni WEBROOT" >&2
                exit 64
                ;;
              *)
                break
                ;;
            esac
          done
          if [ "\$#" -ne 2 ]; then
            echo "usage: i7-release-web [--glulx|--zcode] [--force] SOURCE.ni WEBROOT" >&2
            exit 64
          fi

          source="\$1"
          webroot="\$2"
          if [ ! -f "\$source" ]; then
            echo "i7-release-web: source file not found: \$source" >&2
            exit 66
          fi
          if [ -e "\$webroot" ] && [ "\$force" -ne 1 ] && [ -n "\$(find "\$webroot" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
            echo "i7-release-web: output directory is not empty: \$webroot" >&2
            echo "Use --force to replace it." >&2
            exit 73
          fi

          work="\$(mktemp -d)"
          trap 'rm -rf "\$work"' EXIT
          project="\$work/Story.inform"
          materials="\$work/Story.materials"
          mkdir -p "\$project/Source" "\$project/Build" "\$materials"

          hash="\$(${pkgs.coreutils}/bin/sha256sum "\$source" | ${pkgs.coreutils}/bin/cut -c1-32)"
          uuid="\$(printf '%s-%s-%s-%s-%s\n' \
            "\$(${pkgs.coreutils}/bin/printf '%s' "\$hash" | ${pkgs.coreutils}/bin/cut -c1-8)" \
            "\$(${pkgs.coreutils}/bin/printf '%s' "\$hash" | ${pkgs.coreutils}/bin/cut -c9-12)" \
            "\$(${pkgs.coreutils}/bin/printf '%s' "\$hash" | ${pkgs.coreutils}/bin/cut -c13-16)" \
            "\$(${pkgs.coreutils}/bin/printf '%s' "\$hash" | ${pkgs.coreutils}/bin/cut -c17-20)" \
            "\$(${pkgs.coreutils}/bin/printf '%s' "\$hash" | ${pkgs.coreutils}/bin/cut -c21-32)")"
          printf '%s\n' "\$uuid" > "\$project/uuid.txt"

          ${pkgs.coreutils}/bin/cp "\$source" "\$project/Source/story.ni"
          if ! ${pkgs.gnugrep}/bin/grep -qi '^[[:space:]]*Release along with .*interpreter' "\$project/Source/story.ni"; then
            {
              printf '\n'
              printf 'Release along with a website and an interpreter.\n'
            } >> "\$project/Source/story.ni"
          fi

          case "\$format" in
            glulx)
              i7_format=Inform6/32
              i6_switches=-wG
              story_file="\$project/Build/output.ulx"
              blorb_file="\$project/Build/output.gblorb"
              ;;
            zcode)
              i7_format=Inform6/16
              i6_switches=-wv8
              story_file="\$project/Build/output.z8"
              blorb_file="\$project/Build/output.zblorb"
              ;;
          esac

          "$out/bin/inform7" -release -project "\$project" -format="\$i7_format" -no-progress -no-index -no-problems
          ${pkgs.inform6}/bin/inform "\$i6_switches" '\$MAX_STATIC_DATA=500000' '\$MAX_ZCODE_SIZE=524288' "\$project/Build/auto.inf" "\$story_file"
          inblorb_log="\$work/inblorb.log"
          "$out/bin/inblorb" "\$project/Release.blurb" "\$blorb_file" | ${pkgs.coreutils}/bin/tee "\$inblorb_log"

          blorb_dest="\$(${pkgs.gnused}/bin/sed -n 's/^Copy blorb to: \\[\\[\\(.*\\)\\]\\]$/\\1/p' "\$inblorb_log" | ${pkgs.coreutils}/bin/tail -n 1)"
          if [ -n "\$blorb_dest" ]; then
            mkdir -p "\$(${pkgs.coreutils}/bin/dirname "\$blorb_dest")"
            ${pkgs.coreutils}/bin/cp "\$blorb_file" "\$blorb_dest"
          fi
          if [ ! -f "\$materials/Release/Cover.jpg" ] && [ -f "\$materials/Release/DefaultCover.jpg" ]; then
            ${pkgs.coreutils}/bin/cp "\$materials/Release/DefaultCover.jpg" "\$materials/Release/Cover.jpg"
          fi

          if [ "\$force" -eq 1 ]; then
            rm -rf "\$webroot"
          fi
          mkdir -p "\$webroot"
          ${pkgs.coreutils}/bin/cp -R "\$materials/Release/." "\$webroot/"
          echo "Wrote web release to \$webroot"
          EOF
          chmod +x $out/bin/i7-release-web
        '';

      in {
        packages = {
          inherit inweb intest inform glulxe remglk glulxe-remglk;
          inform-unwrapped = informUnwrapped;
          default = inform;
        };

        apps = {
          inform7 = {
            type = "app";
            program = "${inform}/bin/inform7";
          };
          i7-check = {
            type = "app";
            program = "${inform}/bin/i7-check";
          };
          i7-build = {
            type = "app";
            program = "${inform}/bin/i7-build";
          };
          i7-play = {
            type = "app";
            program = "${inform}/bin/i7-play";
          };
          i7-play-remglk = {
            type = "app";
            program = "${inform}/bin/i7-play-remglk";
          };
          i7-release-web = {
            type = "app";
            program = "${inform}/bin/i7-release-web";
          };
          glulxe = {
            type = "app";
            program = "${glulxe}/bin/glulxe";
          };
          glulxe-remglk = {
            type = "app";
            program = "${glulxe-remglk}/bin/glulxe-remglk";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ inweb intest inform glulxe remglk glulxe-remglk pkgs.inform6 pkgs.frotz ];
        };
      }
    );
}
