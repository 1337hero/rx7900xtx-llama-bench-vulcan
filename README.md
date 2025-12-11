# AMD RX 7900 XTX Vulkan Benchmarks for llama.cpp

Benchmark results for dual AMD Radeon RX 7900 XTX GPUs using the Vulkan backend with [llama.cpp](https://github.com/ggerganov/llama.cpp).

Results formatted for the [Vulkan Scoreboard discussion #10879](https://github.com/ggml-org/llama.cpp/discussions/10879).

## Latest Results (2025-12-11)

### Single GPU (Compute Card)

| model | size | params | backend | ngl | n_batch | fa | test | t/s |
|-------|-----:|-------:|---------|----:|--------:|---:|-----:|----:|
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 512 | 1 | pp512 | **3290.92 ± 37.67** |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 512 | 1 | tg128 | **172.86 ± 0.23** |

### Dual GPU

| model | size | params | backend | ngl | n_batch | fa | test | t/s |
|-------|-----:|-------:|---------|----:|--------:|---:|-----:|----:|
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 512 | 1 | pp512 | 2546.13 ± 18.25 |
| llama 7B Q4_0 | 3.56 GiB | 6.74 B | Vulkan | 100 | 512 | 1 | tg128 | 129.80 ± 0.34 |

> **Note:** Dual GPU is slower than single GPU for small models due to PCIe transfer overhead. Dual GPU shines with larger models (70B+) that benefit from combined VRAM.

Build: `a81a56957` (7361)

---

## Optimal Settings for RDNA3

As of late 2025, the recommended settings for 7900 XTX are:

```bash
# Coopmat works now - no need to disable it
GGML_VK_VISIBLE_DEVICES=1 llama-bench -m model.gguf -ngl 100 -fa 1 -b 512
```

| Setting | Value | Notes |
|---------|-------|-------|
| **Coopmat** | Enabled | `KHR_coopmat` now works correctly on RDNA3 |
| **Flash Attention** | `-fa 1` | ~5% improvement on token generation |
| **Batch Size** | `-b 512` | Optimal for 7900 XTX |

### Historical Note

Earlier in 2025, RDNA3 required workarounds (`GGML_VK_DISABLE_COOPMAT=1`, `-b 256`) due to driver/llama.cpp issues. These are no longer needed with Mesa 25.3+ and recent llama.cpp builds.

---

## Critical: BIOS & Hardware Setup

Getting full performance from 7900 XTX requires proper BIOS configuration. Without these, you may see 50-75% lower performance.

### 1. Enable ReBAR (Resizable BAR)

In BIOS:
1. Settings → IO Ports → **Above 4G Decoding** = Enabled
2. Settings → IO Ports → **Re-Size BAR Support** = Enabled

Verify with:
```bash
lspci -v -s <GPU_BUS_ID> | grep -i size
# Should show "size=32G" not "size=256M"
```

### 2. Use Direct CPU PCIe Lanes

Not all PCIe slots are equal. On X570/X670 motherboards:
- **Top slot** = Direct CPU lanes (x16 @ 16GT/s) ← Use this for compute
- **Bottom slots** = Often routed through chipset (much slower)

Verify with:
```bash
sudo lspci -vvv -s <GPU_BUS_ID> | grep -iE "LnkCap:|LnkSta:"
# Should show: Speed 16GT/s, Width x16
```

### Performance Impact

| Configuration | pp512 | tg128 |
|--------------|-------|-------|
| ReBAR off, bad PCIe | ~760 | ~86 |
| ReBAR on, x16 lanes | **~3290** | **~173** |

That's **4x prompt processing** and **2x token generation**!

---

## System Configuration

| Component | Details |
|-----------|---------|
| **CPU** | AMD Ryzen 7 5800X |
| **Motherboard** | Gigabyte X570 AORUS XTREME |
| **GPUs** | 2x AMD Radeon RX 7900 XTX (24GB each) |
| **OS** | Arch Linux 6.17.9-zen1-1-zen |
| **Vulkan Driver** | RADV (Mesa 25.3.1-arch1.2) |
| **ReBAR** | Enabled (32GB BAR) |

**Device Info:**
```
AMD Radeon RX 7900 XTX (RADV NAVI31) | fp16: 1 | warp size: 64 | int dot: 1 | matrix cores: KHR_coopmat
```

### GPU Slot Configuration

| Slot | PCI Bus | PCIe Link | Role |
|------|---------|-----------|------|
| Top (slot 1) | 0f:00.0 | x16 @ 16GT/s (CPU direct) | Compute (headless) |
| Bottom (slot 3) | 06:00.0 | x16 @ 16GT/s (chipset) | Display |

---

## Usage

### Quick Start

```bash
./benchmark-vulkan.sh
```

### With 70B Model

```bash
MODEL_70B=/path/to/70B-model.gguf ./benchmark-vulkan.sh
```

### Manual Benchmark

```bash
# Single GPU (use GPU 1 for compute if display is on GPU 0)
GGML_VK_VISIBLE_DEVICES=1 llama-bench \
  -m /path/to/model.gguf -ngl 100 -fa 1 -b 512

# Dual GPU
GGML_VK_VISIBLE_DEVICES=0,1 llama-bench \
  -m /path/to/model.gguf -ngl 100 -fa 1 -b 512
```

### Check GPU Mapping

```bash
vulkaninfo 2>/dev/null | grep -E "(deviceName|pciBus)"
```

---

## Troubleshooting

### Low performance (~500-1000 t/s instead of ~3000+ t/s)

1. **Check ReBAR:** `lspci -v -s <BUS> | grep size` should show 32G
2. **Check PCIe link:** `sudo lspci -vvv -s <BUS> | grep LnkSta` should show x16 @ 16GT/s
3. **Check power state:** `cat /sys/class/drm/card*/device/power_state` - D0 = awake, D3hot = asleep

### Wake sleeping GPU

```bash
sudo bash -c 'echo on > /sys/class/drm/card0/device/power/control'
```

### Building Vulkan Backend

```bash
cd llama.cpp
cmake -B build-vulkan -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build-vulkan --config Release -j $(nproc)
```

---

## License

MIT License
