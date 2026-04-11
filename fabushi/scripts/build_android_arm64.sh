#!/bin/bash
# 交叉编译 llama.cpp 全套 native 库 (Android arm64-v8a)
# 解决 libmtmd.so 缺少 libc++_shared.so 链接导致的 dlopen 失败

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LLAMA_SRC="${PROJECT_ROOT}/native_libs/llama.cpp"
BUILD_DIR="${PROJECT_ROOT}/native_libs/llama.cpp/build-android-arm64"
OUTPUT_DIR="${PROJECT_ROOT}/android/app/src/main/jniLibs/arm64-v8a"

# NDK 路径
NDK_PATH="/Users/gloriachan/Library/Android/sdk/ndk/27.0.12077973"
TOOLCHAIN="${NDK_PATH}/build/cmake/android.toolchain.cmake"

if [ ! -f "$TOOLCHAIN" ]; then
    echo "❌ 找不到 NDK toolchain: $TOOLCHAIN"
    exit 1
fi

echo "🔧 配置信息："
echo "  LLAMA_SRC: ${LLAMA_SRC}"
echo "  BUILD_DIR: ${BUILD_DIR}"
echo "  OUTPUT_DIR: ${OUTPUT_DIR}"
echo "  NDK: ${NDK_PATH}"
echo ""

# 清理旧构建
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "📦 正在配置 CMake (Android arm64-v8a, c++_shared)..."
cmake -S "${LLAMA_SRC}" -B "${BUILD_DIR}" \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DANDROID_STL=c++_shared \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_CURL=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=OFF \
    -DLLAMA_BUILD_TOOLS=ON \
    -DLLAMA_NATIVE=OFF \
    -DGGML_OPENMP=OFF \
    -DGGML_VULKAN=OFF \
    -DGGML_OPENCL=OFF \
    -DGGML_METAL=OFF \
    -DGGML_CUDA=OFF

echo ""
echo "🔨 正在编译 ($(sysctl -n hw.ncpu) 线程)..."
cmake --build "${BUILD_DIR}" --config Release -j$(sysctl -n hw.ncpu) -- -k 2>&1 || true

echo ""
echo "📋 编译产物："
find "${BUILD_DIR}" -name "*.so" -type f | sort

echo ""
echo "📦 正在复制 .so 文件到 jniLibs..."
mkdir -p "${OUTPUT_DIR}"

# 复制核心库
for lib in libllama.so libggml.so libggml-cpu.so libggml-base.so libmtmd.so; do
    SO_FILE=$(find "${BUILD_DIR}" -name "$lib" -type f | head -1)
    if [ -n "$SO_FILE" ]; then
        cp -v "$SO_FILE" "${OUTPUT_DIR}/"
    else
        echo "⚠️  未找到: $lib"
    fi
done

# 复制 libc++_shared.so（从 NDK）
LIBCPP="${NDK_PATH}/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"
if [ -f "$LIBCPP" ]; then
    cp -v "$LIBCPP" "${OUTPUT_DIR}/"
else
    echo "⚠️  未找到 libc++_shared.so，尝试其他路径..."
    LIBCPP2=$(find "${NDK_PATH}" -name "libc++_shared.so" -path "*aarch64*" | head -1)
    if [ -n "$LIBCPP2" ]; then
        cp -v "$LIBCPP2" "${OUTPUT_DIR}/"
    else
        echo "❌ 无法找到 libc++_shared.so"
    fi
fi

echo ""
echo "🔍 验证 libmtmd.so 的 NEEDED 依赖..."
READELF="${NDK_PATH}/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf"
if [ -x "$READELF" ]; then
    $READELF -d "${OUTPUT_DIR}/libmtmd.so" | grep -E "NEEDED|SONAME"
else
    echo "⚠️  llvm-readelf 不可用，跳过验证"
fi

echo ""
echo "✅ 完成！输出目录内容："
ls -lh "${OUTPUT_DIR}/"
