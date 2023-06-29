{
  description = "Prometheus SLI generator";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in
    {

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          sloth = pkgs.buildGoModule {
            pname = "sloth";
            inherit version;
            # In 'nix develop', we don't need a copy of the source tree
            # in the Nix store.
            src = ./.;
            subPackages = [ "cmd/sloth" ];
            # modRoot = "cmd";
            # preBuild = ''
            #   go mod vendor
            # '';
            ldflags = [
              "-s"
              "-w"
              "-X main.version=${version}"
              # "-X main.commit=${commit}"
            ];
            # CGO_ENABLED=0 go build -trimpath -ldflags='-X main.version=$(sloth_VERSION) -X main.commit=$(sloth_COMMIT) -s -w' ./cmd/sloth

            # This hash locks the dependencies of this package. It is
            # necessary because of how Go requires network access to resolve
            # VCS.  See https://www.tweag.io/blog/2021-03-04-gomod2nix/ for
            # details. Normally one can build with a fake sha256 and rely on native Go
            # mechanisms to tell you what the hash should be or determine what
            # it should be "out-of-band" with other tooling (eg. gomod2nix).
            # To begin with it is recommended to set this, but one must
            # remeber to bump this hash when your dependencies change.
            # vendorSha256 = pkgs.lib.fakeSha256;

            # vendorHash = null;

            # proxyVendor = true;
            vendorSha256 = "sha256-APIqB8P7Zfta62RPhy3iLcQNeYBZZgRjw5LC0A18ES0=";

            # Needed for running the tests
            nativeBuildInputs = with pkgs; [ curl perl git ];
          };
        });

      # Add dependencies that are only needed for development
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ go gopls gotools go-tools ];
          };
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.sloth);



      # A NixOS module, if applicable (e.g. if the package provides a system service).
      #   nixosModules.sloth =
      #
      #     { pkgs, ... }:
      #     {
      #       environment.systemPackages = [ self.packages.${system}.sloth ];
      #     };
    };
}

