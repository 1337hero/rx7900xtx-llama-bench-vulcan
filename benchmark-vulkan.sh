#!/bin/bash
#
# Vulkan Benchmark Script for llama.cpp Discussion #10879
# https://github.com/ggml-org/llama.cpp/discussions/10879
#
# System: 2x AMD Radeon RX 7900 XTX (24GB each)
# Backend: Vulkan via RADV/Mesa
#
# RDNA3 Optimizations:
#   - GGML_VK_DISABLE_COOPMAT=1 : coopmat is currently slower on RDNA3
#   - -b 256 : avoids batch size 512 performance cliff on 7900 XTX
#   See: https://github.com/ggml-org/llama.cpp/issues/10966
#

set -e

# Configuration
LLAMA_CPP_DIR="$HOME/Projects/0_AI/llama.cpp"
VULKAN_BUILD_DIR="$LLAMA_CPP_DIR/build-vulkan"
LLAMA_BENCH="$VULKAN_BUILD_DIR/bin/llama-bench"
MODEL_DIR="$LLAMA_CPP_DIR/models"
MODEL_7B="$MODEL_DIR/llama-2-7b.Q4_0.gguf"
MODEL_70B="${MODEL_70B:-}"

OUTPUT_DIR="$HOME/Projects/0_AI/AMD-RX7900XTX-VULCAN/benchmark-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="$OUTPUT_DIR/vulkan_benchmark_$TIMESTAMP.txt"

# RDNA3 Vulkan optimizations
export GGML_VK_DISABLE_COOPMAT=1
BATCH_SIZE=256

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
echo_success() { echo -e "${GREEN}[OK]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

mkdir -p "$OUTPUT_DIR"

# --- PRE-FLIGHT CHECKS (not captured to file) ---

echo_info "Checking prerequisites..."

# Check for Vulkan build, build if needed
if [ ! -f "$LLAMA_BENCH" ]; then
    echo_warn "Vulkan build not found at $VULKAN_BUILD_DIR"
    echo ""
    read -p "Build llama.cpp with Vulkan backend now? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo_info "Building llama.cpp with Vulkan backend..."
        mkdir -p "$VULKAN_BUILD_DIR"
        cd "$VULKAN_BUILD_DIR"
        cmake .. -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
        cmake --build . --config Release -j $(nproc)
        echo_success "Vulkan build complete"
    else
        echo_error "Cannot proceed without Vulkan build"
        exit 1
    fi
fi

# Check/Download 7B model (BEFORE output capture)
if [ ! -f "$MODEL_7B" ]; then
    echo_warn "Llama-2-7B Q4_0 model not found at $MODEL_7B"
    echo_info "Downloading from HuggingFace..."
    wget -q --show-progress -O "$MODEL_7B" \
        "https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q4_0.gguf"
    echo_success "Downloaded 7B model"
fi

echo_success "Prerequisites OK"
echo_info "RDNA3 optimizations: GGML_VK_DISABLE_COOPMAT=1, batch_size=$BATCH_SIZE"
echo ""

# --- START OUTPUT CAPTURE (benchmarks only) ---

{
echo "=============================================="
echo "  Vulkan Benchmark for llama.cpp"
echo "  Thread: https://github.com/ggml-org/llama.cpp/discussions/10879"
echo "  Date: $(date)"
echo "=============================================="
echo ""

# System Information
echo "=== SYSTEM INFORMATION ==="
echo "OS: $(uname -s) $(uname -r)"
echo "Distro: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Unknown')"
echo ""

# Vulkan Information
echo "=== VULKAN INFORMATION ==="
vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverName|driverVersion|driverInfo" | head -8
echo ""

# llama.cpp Build Info
cd "$LLAMA_CPP_DIR"
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo "=== BUILD INFO ==="
echo "Commit: $COMMIT_HASH"
echo "Model: $MODEL_7B"
echo ""

# RDNA3 Optimizations
echo "=== RDNA3 OPTIMIZATIONS ==="
echo "GGML_VK_DISABLE_COOPMAT=1 (coopmat slower on RDNA3)"
echo "Batch size: $BATCH_SIZE (avoids pp512 performance cliff)"
echo "See: https://github.com/ggml-org/llama.cpp/issues/10966"
echo ""

# --- CANONICAL 7B BENCHMARKS ---
echo "=============================================="
echo "  CANONICAL 7B Q4_0 BENCHMARKS"
echo "=============================================="
echo ""

echo "### GPU 0 ONLY ###"
GGML_VK_VISIBLE_DEVICES=0 $LLAMA_BENCH -m "$MODEL_7B" -ngl 100 -fa 0,1 -b $BATCH_SIZE
echo ""

echo "### GPU 1 ONLY ###"
GGML_VK_VISIBLE_DEVICES=1 $LLAMA_BENCH -m "$MODEL_7B" -ngl 100 -fa 0,1 -b $BATCH_SIZE
echo ""

echo "### DUAL GPU ###"
GGML_VK_VISIBLE_DEVICES=0,1 $LLAMA_BENCH -m "$MODEL_7B" -ngl 100 -fa 0,1 -b $BATCH_SIZE
echo ""

# --- 70B BENCHMARKS (if model exists) ---
if [ -n "$MODEL_70B" ] && [ -f "$MODEL_70B" ]; then
    echo "=============================================="
    echo "  70B Q4_K_M BENCHMARKS (EXTRA)"
    echo "=============================================="
    echo ""
    echo "Model: $MODEL_70B"
    echo ""

    echo "### 70B DUAL GPU ###"
    GGML_VK_VISIBLE_DEVICES=0,1 $LLAMA_BENCH -m "$MODEL_70B" -ngl 100 -fa 0,1 -b $BATCH_SIZE
    echo ""
fi

echo "=============================================="
echo "  BENCHMARK COMPLETE"
echo "=============================================="

} 2>&1 | tee "$OUTPUT_FILE"

echo ""
echo -e "${GREEN}Results saved to:${NC} $OUTPUT_FILE"
echo ""
echo "Paste the contents of this file back to Claude to generate"
echo "the formatted GitHub comment for discussion #10879."
