#!/usr/bin/env bash
# End-to-end test: creates a tiny Bazel + GCC project and drives the real Neovim config
# headless against it (clangd navigation/completion + GCC diagnostics via BEP).
#   tests/e2e.sh [project-dir]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="${1:-$(mktemp -d)/bzdemo}"
rm -rf "$P" && mkdir -p "$P/lib" "$P/app"

echo "8.4.2" > "$P/.bazelversion"
cat > "$P/MODULE.bazel" <<'EOF'
module(name = "bzdemo")
bazel_dep(name = "rules_cc", version = "0.1.1")
EOF
cat > "$P/lib/BUILD.bazel" <<'EOF'
load("@rules_cc//cc:defs.bzl", "cc_library")
cc_library(
    name = "greet",
    srcs = ["greet.cc"],
    hdrs = ["greet.h"],
    visibility = ["//visibility:public"],
)
EOF
cat > "$P/lib/greet.h" <<'EOF'
#pragma once
#include <string>
namespace lib {
std::string greet(const std::string& who);
}
EOF
cat > "$P/lib/greet.cc" <<'EOF'
#include "lib/greet.h"
namespace lib {
__attribute__((noinline)) int helper() { return 1; }
// GCC-only builtin: clang (and therefore clangd) reports a bogus error here.
static_assert(__builtin_has_attribute(helper, noinline), "gcc extension");
std::string greet(const std::string& who) {
  int unused = 42;
  return "hello, " + who;
}
}
EOF
cat > "$P/app/BUILD.bazel" <<'EOF'
load("@rules_cc//cc:defs.bzl", "cc_binary")
cc_binary(
    name = "app",
    srcs = ["main.cc"],
    deps = ["//lib:greet"],
)
EOF
cat > "$P/app/main.cc" <<'EOF'
#include <iostream>
#include <vector>
#include "lib/greet.h"
int main() {
  std::vector<int> v{1, 2, 3};
  std::cout << lib::greet("bazel") << " " << v.size() << "\n";
  return 0;
}
EOF

echo "== warm-up build in the terminal (populates the action cache) =="
(cd "$P" && bazel build //... --color=no 2>&1 | grep -E "warning|error|Build completed" || true)

echo "== headless nvim =="
cd "$P"
BZDEMO="$P" nvim --headless -c "luafile $HERE/e2e.lua" 2>&1
