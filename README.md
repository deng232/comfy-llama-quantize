# ComfyUI-GGUF llama-quantize

Static Linux builds of `llama-quantize`, patched to support ComfyUI diffusion
GGUF models.

## Sources

- [`llama.cpp` b3962](https://github.com/ggml-org/llama.cpp/tree/c8c07d658a6cefc5a50cfdf6be7d726503612303)
- `main`: [`city96/ComfyUI-GGUF`](https://github.com/city96/ComfyUI-GGUF/tree/6ea2651e7df66d7585f6ffee804b20e92fb38b8a)
- `krea2-patch`: [`molbal/ComfyUI-GGUF`](https://github.com/molbal/ComfyUI-GGUF/tree/b6016439f135342819461256ec5f03fbb4003a8b), with Krea 2 support

## Builds

```sh
# Portable static build used for releases
nix build

# CPU-optimized static build
nix build .#native

# Convert a checkpoint to F16/BF16 GGUF using uv's cache
nix run .#converter -- --src model.safetensors
```

The `native` package enables `GGML_NATIVE`, allowing compiler optimizations for
the build machine's CPU. It may be faster, but the resulting binary is not
guaranteed to run on older or different CPUs. Use the default package for
distribution.

Upstream code remains subject to the MIT and Apache-2.0 licenses in the linked
source repositories.
