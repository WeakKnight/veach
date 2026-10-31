# Temporary slangc for NRD

`npm run build:nrd` needs a slangc that emits WGSL `texture-formats-tier1` storage formats
(`r16float`, `r8unorm`, ...). Slang 2026.20 writes `rgba32float` for them. This directory holds a
Windows x64 Release build until [shader-slang/slang#13778](https://github.com/shader-slang/slang/pull/13778)
ships in a release. Then delete it, raise `SLANG_VERSION` in `scripts/build-shaders.mjs` and drop the
`tools/slang` candidate from `findSlangc` in `scripts/build-nrd.mjs`.

`build:nrd` uses `bin/slangc.exe` unless `SLANGC` is set. `build:shaders` and the other scripts still use
the pinned release in `.tools/slang`.

## Source

- Fork: https://github.com/WeakKnight/slang, branch `veach/wgsl-tier1-formats`
  (local in `E:/GitHub/slang`, not pushed)
- Commit `9a9b6041f07328915ea007283d600b0f2d3d1e38`: upstream master `e638298fe` (2026-10-30)
  merged with PR #13778 head `9cfc373449a2`
- Files: `bin/slangc.exe`, `bin/slang-compiler.dll` (all WGSL compilation needs), `LICENSE`
  (Apache-2.0 WITH LLVM-exception)

## Rebuild

```sh
cd E:/GitHub/slang
git checkout veach/wgsl-tier1-formats
# On a Chinese (code page 936) Windows, cl needs UTF-8 sources: cmark warns C4819 as an error.
CL=-utf-8 cmake --build build --config Release --target slangc
cp build/Release/bin/slangc.exe build/Release/bin/slang-compiler.dll <veach>/tools/slang/bin/
```

slangc writes a `slang-glsl-module.bin` cache next to itself (gitignored).
