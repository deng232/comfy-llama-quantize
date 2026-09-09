{
  description = "Statically linked ComfyUI-GGUF llama-quantize";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    llama-cpp = {
      url = "github:ggml-org/llama.cpp/c8c07d658a6cefc5a50cfdf6be7d726503612303";
      flake = false;
    };

    comfyui-gguf = {
      url = "github:molbal/ComfyUI-GGUF/b6016439f135342819461256ec5f03fbb4003a8b";
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
          pname = "molbal-comfyui-gguf-llama-quantize-static${nixpkgs.lib.optionalString native "-native"}";
          version = "b3962-krea2";

          src = llama-cpp;
          patches = [ "${comfyui-gguf}/tools/lcpp.patch" ];

          postPatch = ''
            grep -q 'LLM_ARCH_KREA2' src/llama.cpp
            grep -q '"krea2"' src/llama.cpp
          '';

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
            install -Dm755 bin/llama-quantize "$out/bin/llama-quantize-krea2"
            runHook postInstall
          '';

          doInstallCheck = true;
          installCheckPhase = ''
            runHook preInstallCheck

            binary="$out/bin/llama-quantize-krea2"
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
            grep -q 'Q4_K_M' <<<"$help_output"
            grep -q 'Q5_K_M' <<<"$help_output"

            runHook postInstallCheck
          '';

          meta = {
            description = "Static llama-quantize patched by molbal for ComfyUI diffusion GGUF models with Krea2 support";
            homepage = "https://github.com/molbal/ComfyUI-GGUF";
            license = nixpkgs.lib.licenses.mit;
            mainProgram = "llama-quantize-krea2";
            platforms = systems;
          };
        };

      mkConverter =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.writeShellApplication {
          name = "converter";
          runtimeInputs = [
            pkgs.python312
            pkgs.uv
          ];
          text = ''
            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
            ]}:''${LD_LIBRARY_PATH:-}
            exec uv run --no-project --python ${pkgs.python312}/bin/python3 \
              --index https://download.pytorch.org/whl/cpu \
              --with 'gguf>=0.13.0' \
              --with torch \
              --with tqdm \
              --with safetensors \
              ${comfyui-gguf}/tools/convert.py "$@"
          '';
        };
    in
    {
      packages = eachSystem (system: {
        default = mkLlamaQuantize system false;
        converter = mkConverter system;
        llama-quantize-static = mkLlamaQuantize system false;
        native = mkLlamaQuantize system true;
      });

      apps = eachSystem (system: {
        default = {
          type = "app";
          program = "${mkLlamaQuantize system false}/bin/llama-quantize-krea2";
        };
        #UV_CACHE_DIR=/data/.cache/uv specify cache location if not default ~/.cache/uv
        converter = {
          type = "app";
          program = "${mkConverter system}/bin/converter";
        };
      });

      checks = eachSystem (system: {
        static-binary = mkLlamaQuantize system false;
      });
    };
}
