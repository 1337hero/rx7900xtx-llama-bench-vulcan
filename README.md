# AMD RX 7900 XTX Vulkan Benchmarks for llama.cpp

Benchmark results for dual AMD Radeon RX 7900 XTX GPUs using the Vulkan backend with [llama.cpp](https://github.com/ggerganov/llama.cpp).

Results formatted for the [Vulkan Scoreboard discussion #10879](https://github.com/ggml-org/llama.cpp/discussions/10879).

## About This Benchmark

The `benchmark-vulkan.sh` script runs the canonical `llama-bench` tests used by the llama.cpp community to compare GPU performance across different hardware.

### What It Tests

| Test | Description |
|------|-------------|
| **pp512** | Prompt processing speed (512 tokens) - measures how fast the model processes input |
| **tg128** | Token generation speed (128 tokens) - measures inference/output speed |
| **fa=0** | Flash Attention disabled |
| **fa=1** | Flash Attention enabled |

### Key Flags

| Flag | Purpose |
|------|---------|
| `-ngl 100` | Offload all layers to GPU |
| `-fa 0,1` | Test both with and without Flash Attention |
| `-b 256` | Batch size (RDNA3 optimization) |
| `GGML_VK_VISIBLE_DEVICES=N` | Select specific GPU(s) |

---

## RDNA3 Vulkan Optimizations

**Important:** The default llama.cpp Vulkan settings are not optimal for RDNA3 (7900 XTX). Two key tweaks significantly improve performance:

### 1. Disable Cooperative Matrix

```bash
export GGML_VK_DISABLE_COOPMAT=1
```

The `KHR_coopmat` codepath is currently slower on RDNA3. Disabling it improves pp512 by ~40-60%.

### 2. Use Batch Size 256

```bash
llama-bench ... -b 256
```

There's a known performance cliff at batch size 512 on 7900 XTX. Using `-b 256` avoids this issue.

See: [GitHub Issue #10966](https://github.com/ggml-org/llama.cpp/issues/10966)

### Performance Impact

| Setting | pp512 (fa=1) |
|---------|-------------|
| Default (b=512, coopmat on) | ~490 t/s |
| Optimized (b=256, coopmat off) | ~1030 t/s |

**That's a 2x improvement!**

---

## Usage

### Basic (7B Canonical Test)

```bash
./benchmark-vulkan.sh
```

### With 70B Model

```bash
MODEL_70B=/path/to/your/70B-model.gguf ./benchmark-vulkan.sh
```

### Manual Run with Optimizations

```bash
GGML_VK_DISABLE_COOPMAT=1 GGML_VK_VISIBLE_DEVICES=0 \
  llama-bench -m model.gguf -ngl 100 -fa 0,1 -b 256
```

### Customization

Edit `benchmark-vulkan.sh` to modify:

- `LLAMA_CPP_DIR` - Path to your llama.cpp installation
- `VULKAN_BUILD_DIR` - Path to Vulkan build (default: `build-vulkan`)
- `MODEL_DIR` - Where to store/find models
- `BATCH_SIZE` - Adjust if needed for your GPU

---

## System Configuration

| Component | Details |
|-----------|---------|
| **OS** | Arch Linux 6.12.61-1-lts |
| **Vulkan Driver** | RADV (Mesa 25.3.1-arch1.2) |
| **GPUs** | 2x AMD Radeon RX 7900 XTX (24GB each) |
| **Architecture** | RDNA3, gfx1100 |
| **Build** | `34ce48d97` (7356) |

**Device Info:**
```
AMD Radeon RX 7900 XTX (RADV NAVI31) | fp16: 1 | warp size: 64 | int dot: 1
```

### PCIe Topology Note

On this system (Gigabyte X570 AORUS XTREME):
- **GPU 0** (Vulkan device 0): Direct CPU PCIe 4.0 x16 — full bandwidth
- **GPU 1** (Vulkan device 1): Routed through X570 chipset — x4 uplink bottleneck

This is a motherboard limitation with triple-slot GPUs (only slots 1 and 3 are usable, slot 3 goes through chipset). GPU 1 shows reduced Vulkan performance due to this bottleneck. **For scoreboard purposes, GPU 0 results are representative.**

ROCm/HIP does not exhibit this same sensitivity to the chipset bottleneck for LLM inference workloads.

---

## Benchmark Results

### Canonical 7B Q4_0 Results (for Scoreboard)

**GPU 0 (Direct CPU PCIe):**

| model | size | params | backend | ngl | n_batch | fa | test | t/s |
|-------|-----:|-------:|---------|----:|--------:|---:|-----:|----:|
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 0 | pp512 | 758.55 ± 12.18 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 0 | tg128 | 86.29 ± 0.09 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 1 | pp512 | 1029.28 ± 0.82 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 1 | tg128 | 129.21 ± 0.24 |

**GPU 1 (Chipset-bottlenecked — not representative):**

| model | size | params | backend | ngl | n_batch | fa | test | t/s |
|-------|-----:|-------:|---------|----:|--------:|---:|-----:|----:|
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 0 | pp512 | 205.19 ± 0.34 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 0 | tg128 | 32.03 ± 0.02 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 1 | pp512 | 288.42 ± 0.94 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 1 | tg128 | 57.72 ± 0.01 |

---

### Dual-GPU Results

Despite GPU 1's chipset bottleneck, dual-GPU still provides good combined throughput:

| model | size | params | backend | ngl | n_batch | fa | test | t/s |
|-------|-----:|-------:|---------|----:|--------:|---:|-----:|----:|
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 0 | pp512 | 1898.68 ± 8.87 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 0 | tg128 | 85.30 ± 0.11 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 1 | pp512 | 2043.45 ± 19.39 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 256 | 1 | tg128 | 105.00 ± 0.25 |

---

## Vulkan vs ROCm Comparison

On the same hardware, ROCm significantly outperforms Vulkan for this GPU:

| Backend | pp512 (fa=1) | tg128 (fa=1) |
|---------|-------------|--------------|
| **ROCm** | 3,785 t/s | 126 t/s |
| **Vulkan** | 1,029 t/s | 129 t/s |

ROCm is ~3.7x faster for prompt processing. Token generation is similar. **For AMD GPUs, ROCm is the recommended backend when available.**

---

## Troubleshooting

### Low pp512 performance (~500 t/s instead of ~1000+ t/s)

Make sure you're using the RDNA3 optimizations:
```bash
export GGML_VK_DISABLE_COOPMAT=1
llama-bench ... -b 256
```

### GPU 1 much slower than GPU 0

Check your PCIe topology with `lspci -tv`. If GPU 1 routes through chipset, this is expected. Use GPU 0 for single-GPU benchmarks.

### Building Vulkan backend

```bash
cd llama.cpp
mkdir build-vulkan && cd build-vulkan
cmake .. -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release -j $(nproc)
```

---

## License

MIT License

