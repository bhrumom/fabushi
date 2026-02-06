#!/bin/bash

# 复制 llama.cpp 动态库到应用的 Frameworks 目录
# 这个脚本在 Xcode Build Phases 中作为 Run Script 执行

set -e

LIBS_DIR="${PROJECT_DIR}/Runner/Libs"
FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
RESOURCES_DIR="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

# 创建目录（如果不存在）
mkdir -p "${FRAMEWORKS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "Copying llama.cpp libraries from ${LIBS_DIR} to ${FRAMEWORKS_DIR}"

# 复制主要的 dylib 文件（只复制不带版本号的 symlinks）
cp -f "${LIBS_DIR}/libllama.dylib" "${FRAMEWORKS_DIR}/"
cp -f "${LIBS_DIR}/libggml.dylib" "${FRAMEWORKS_DIR}/"
cp -f "${LIBS_DIR}/libggml-base.dylib" "${FRAMEWORKS_DIR}/"
cp -f "${LIBS_DIR}/libggml-cpu.dylib" "${FRAMEWORKS_DIR}/"
cp -f "${LIBS_DIR}/libggml-metal.dylib" "${FRAMEWORKS_DIR}/"
cp -f "${LIBS_DIR}/libggml-blas.dylib" "${FRAMEWORKS_DIR}/"

# 复制 Metal shader 文件到 Resources 目录（不是 Frameworks）
echo "Copying Metal shader to ${RESOURCES_DIR}"
cp -f "${LIBS_DIR}/ggml-metal.metal" "${RESOURCES_DIR}/"

echo "llama.cpp libraries copied successfully"

