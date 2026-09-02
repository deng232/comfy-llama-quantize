{
  description = "Statically linked ComfyUI-GGUF llama-quantize";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    llama-cpp = {
      url = "github:ggml-org/llama.cpp/c8c07d658a6cefc5a50cfdf6be7d726503612303";
      flake = false;
    };

    comfyui-gguf = {
      url = "github:city96/ComfyUI-GGUF/6ea2651e7df66d7585f6ffee804b20e92fb38b8a";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      llama-cpp,
      comfyui-gguf,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      eachSystem = nixpkgs.lib.genAttrs systems;

      mkLlamaQuantize =
        system: native:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.pkgsStatic.stdenv.mkDerivation {
          pname = "comfyui-gguf-llama-quantize-static";
          version = "b3962-comfyui-gguf";

          src = llama-cpp;
          patches = [ "${comfyui-gguf}/tools/lcpp.patch" ];

          strictDeps = true;
          nativeBuildInputs = [
            pkgs.binutils
            pkgs.cmake
            pkgs.file
          ];

          cmakeBuildType = "Release";
          cmakeFlags = [
            "-DBUILD_SHARED_LIBS=OFF"
            "-DGGML_CCACHE=OFF"
            "-DGGML_CUDA=OFF"
            "-DGGML_NATIVE=${if native then "ON" else "OFF"}"
            "-DGGML_OPENMP=OFF"
            "-DLLAMA_BUILD_EXAMPLES=ON"
            "-DLLAMA_BUILD_TESTS=OFF"
            "-DLLAMA_CURL=OFF"
            "-DCMAKE_EXE_LINKER_FLAGS=-static"
          ];

          NIX_LDFLAGS = "-static";
          enableParallelBuilding = true;

          buildPhase = ''
            runHook preBuild
            cmake --build . --target llama-quantize --parallel "$NIX_BUILD_CORES"
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 bin/llama-quantize "$out/bin/llama-quantize"
            runHook postInstall
          '';

          doInstallCheck = true;
          installCheckPhase = ''
            runHook preInstallCheck

            binary="$out/bin/llama-quantize"
            file "$binary" | grep -q 'statically linked'

            if readelf -l "$binary" | grep -q 'INTERP'; then
              echo "error: $binary contains a dynamic ELF interpreter" >&2
              exit 1
            fi

            if readelf -d "$binary" | grep -q 'NEEDED'; then
              echo "error: $binary contains dynamic runtime dependencies" >&2
              exit 1
            fi

            help_output="$("$binary" --help 2>&1 || true)"
            grep -qi 'usage:' <<<"$help_output"
            grep -q 'Q5_K_M' <<<"$help_output"

            runHook postInstallCheck
          '';

          meta = {
            description = "Static llama-quantize patched for ComfyUI diffusion GGUF models";
            homepage = "https://github.com/city96/ComfyUI-GGUF";
            license = nixpkgs.lib.licenses.mit;
            mainProgram = "llama-quantize";
            platforms = systems;
          };
        };
    in
    {
      packages = eachSystem (system: {
        default = mkLlamaQuantize system false;
        llama-quantize-static = mkLlamaQuantize system false;
        native = mkLlamaQuantize system true;
      });

      apps = eachSystem (system: {
        default = {
          type = "app";
          program = "${mkLlamaQuantize system false}/bin/llama-quantize";
        };
      });

      checks = eachSystem (system: {
        static-binary = mkLlamaQuantize system false;
      });
    };
}
