{
	description = "ZFS Exporter Flake";

	inputs = {
		nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
		flake-utils.url = github:numtide/flake-utils;
		debBundler = {
			url = github:juliosueiras-nix/nix-utils;
			inputs.nixpkgs.follows = "nixpkgs";
		};
		zfs_exporter-src = {
			url = github:lorenz/zfs_exporter;
			flake = false;
		};
	};

	outputs = { self, nixpkgs, flake-utils, debBundler, zfs_exporter-src }: flake-utils.lib.eachDefaultSystem (system: let
		pkgs = nixpkgs.legacyPackages.${system};
		lib = pkgs.lib;
		buildGoModule = pkgs.buildGoModule;
	in rec {
		packages = rec {
			zfs_exporter = buildGoModule {
				pname = "zfs_exporter";
				version = with lib; with zfs_exporter-src; concatStringsSep "-" [
					"unstable"
					(substring 0 4 lastModifiedDate)
					(substring 4 2 lastModifiedDate)
					(substring 6 2 lastModifiedDate)
				];
				src = zfs_exporter-src;

				vendorHash = "sha256-1Js4bVU6fYwZuZVg27M+jzuPIvPT2yuZOpp580Q0GZg=";

				passthru.deb = debBundler.bundlers.deb {
					inherit system;
					program = "${default}/bin/${default.pname}";
				};

				meta = with lib; {
					description = "Prometheus exporter for ZFS metrics";
					homepage = "https://github.com/lorenz/zfs_exporter";
					license = licenses.asl20;
					maintainers = [ lib.maintainers.illustris ];
					platforms = platforms.unix;
				};
			};
			default = zfs_exporter;
		};

		defaultNixpkgsOverlay = self: super: {
			zfs_exporter = packages.zfs_exporter;
		};

		nixosModules.zfs_exporter = {config, lib, ...}: {
			options.services.zfs_exporter = with lib; {
				enable = mkEnableOption "zfs_exporter";
				port = mkOption {
					type = types.port;
					default = 9700;
					description = "Port the exporter should listen on";
				};
			};

			config = lib.mkIf config.services.zfs_exporter.enable {
				environment.systemPackages = [ packages.zfs_exporter ];
				systemd.services.zfs_exporter = {
					description = "ZFS Exporter";
					after = [ "network.target" ];
					wantedBy = [ "multi-user.target" ];
					serviceConfig = {
						ExecStart = "${packages.zfs_exporter}/bin/zfs_exporter -listen-address :${toString config.services.zfs_exporter.port}";
						User = "nobody";
						Group = "nogroup";
						Restart = "always";
					};
				};
			};
		};
	});
}
