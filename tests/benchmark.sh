#!/usr/bin/env bash
# tests/benchmark.sh - Workstation POSIX & Compilation Benchmark
set -e

echo "=== [1/4] Preparing Environment ==="
cd /tmp
rm -rf redis

echo "=== [2/4] Fetching Redis Source (Shallow) ==="
git clone --depth 1 https://github.com/redis/redis.git
cd redis

echo "=== [3/4] Compiling on $(nproc) Cores (libc malloc) ==="
time make -j$(nproc) MALLOC=libc

echo "=== [4/4] Verifying Binary & Memory Integrity ==="
./src/redis-server --version
./src/redis-server --test-memory 256


echo "=== REDIS SUCCESSFULLY BUILT & VERIFIED ==="
