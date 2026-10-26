# Veach WebGPU Path Tracer - AI Development Guide

Veach is a web path tracer: WebGPU compute shaders written in **Slang** (compiled to WGSL), BVHs built by **tinybvh** compiled to **WebAssembly**, and a TypeScript host. It renders glTF 2.0 assets (and imports `.blend` files). The editor is out of scope for now.

This repository contains the web renderer migrated from Mozi. The original C++ XPU renderer's former `Legacy/` directory remains in the upstream https://github.com/Mozi-Renderer/Mozi Git history for porting reference (BSDFs and lights in `Source/XPU`, pipelines in `Source/Rendering`), not in this repository's history.

## Layout

```
shaders/     Slang sources: Common, Scene (GPU structs, bindings), RayTracing, Materials (incl. BSDF/), Lights, Passes
src/         TypeScript host: accel (tinybvh wrapper), loaders (glTF, HDR, blend), scene, material (graphs -> bytecode),
             render (GPU scene, VT, exposure, sky, ACES, pipelines), app (viewer), view (<veach-view> element),
             generated (committed build outputs)
wasm/        tinybvh C ABI for Emscripten
ThirdParty/  Vendored tinybvh and openpbr-bsdf (see VERSION.txt)
examples/    view (demo of <veach-view>)
tests/       vitest (Node)
scripts/     Build, sample fetching, headless smoke renders
docs/        Design docs (below)
```

## Docs

Read the relevant doc before changing a subsystem, and update it with the change.

| Doc | Covers |
| --- | --- |
| [docs/Architecture.md](docs/Architecture.md) | Full source layout, struct layout, bind groups, BVH format |
| [docs/MaterialSystem.md](docs/MaterialSystem.md) | Material graphs, bytecode, `gMaterialData`, interpreter, procedurals |
| [docs/BSDF.md](docs/BSDF.md) | OpenPBR BSDF port, energy tables, BSDF harness tests |
| [docs/Lights.md](docs/Lights.md) | Emissive triangles, analytic lights, light CDF |
| [docs/VirtualTexturing.md](docs/VirtualTexturing.md) | Page table, feedback, streaming, cache |
| [docs/ExposureAndToneMapping.md](docs/ExposureAndToneMapping.md) | ACES 2.0 LUT, auto exposure, local exposure |
| [docs/Sky.md](docs/Sky.md) | Atmosphere bake, sun |
| [docs/BlendImport.md](docs/BlendImport.md) | `.blend` loader conventions |

## Rules

- `shaders/Scene/SceneTypes.slang` and `src/render/GpuLayout.ts` must match byte for byte (16-byte groups; sizes in Architecture.md).
- WebGPU guarantees only 8 storage buffers per stage, all in use: do not add buffers, pack into existing ones. Bind group layouts are explicit in `PathTracer.ts`.
- Keep CPU references in sync with their shaders: `Interpreter.ts` / `MaterialProgram.slang`, `Procedural.ts` / `Procedural.slang`, `Atmosphere.ts` / `Atmosphere.slang`.
- Emissive triangles are listed in primitive order (`lightOffset + primIdx`) for MIS; underestimated light power is safe, overestimated is not.
- Exposure and tone mapping settings are presentation settings and must never reset accumulation.
- The package is `veach` (`npm run build:lib` -> `dist-lib/`): `src/index.ts` must stay free of DOM side effects; DOM code goes in `src/view` (`veach/view`).
- Generated code is committed. After editing `shaders/` run `npm run build:shaders`; `wasm/` or tinybvh: `npm run build:wasm`; `shaders/Materials/BSDF`, `shaders/Common` or `tests/bsdf`: `npm run build:bsdf-harness`.

## Commands

```sh
npm run dev | build | typecheck | test
npm run build:shaders       # slangc -> src/generated/shaders
npm run build:wasm          # emscripten -> src/generated/tinybvh (-- --debug for symbols/assertions)
npm run build:bsdf-tables   # ThirdParty/openpbr-bsdf data -> src/generated/bsdf/BSDFTables.bin
npm run build:bsdf-harness  # slangc -target cpp + em++ -> tests/generated/bsdf (needs emsdk, GLM)
npm run fetch-samples       # Khronos samples + HDR -> public/samples (gitignored)
npm run smoke               # headless Chrome renders -> .tools/smoke/*.png; fails on GPU/console errors
```

Toolchains live in `.tools/` (gitignored): `slang/`, `emsdk/`.

## Conventions

- TypeScript strict mode, tabs, single quotes, PascalCase types, camelCase members.
- Slang: PascalCase functions and types, `g` prefix for global resources, `[[vk::binding(i, group)]]`.
- Slang math: prefer built-ins (`lerp`, `saturate`, `rcp`, `rsqrt`, `reflect`, `refract`, `isfinite`, `float.getPi()`, ...) over hand-written helpers. Some built-ins (e.g. `max3`/`min3`) require capabilities the WGSL target lacks; only then keep a helper in `Common/Math.slang` and note why.
- Verify changes with `npm test` plus `npm run smoke` and look at the screenshots. Debug view 7 (traversal cost) is useful for BVH work.
- When porting from the historical C++ renderer, keep behavior but fix known legacy issues: normals transform by the inverse transpose, NEE runs whenever the BSDF has lobes light sampling can reach, and emissive selection is power-weighted.
