# Third-party notices

Veach's original code is licensed under the MIT License in `LICENSE`.
Third-party code, derived portions and data retain their respective licenses below;
the top-level MIT license does not replace those terms. These notices and the
`licenses/` directory are included in the npm distribution, even when the corresponding
runtime code or data is embedded in JavaScript or WebAssembly.

## tinybvh

- Upstream: https://github.com/jbikker/tinybvh
- Version: 1.9.1, commit `c9be3103cc9693b456b0a0353927c11cac7d710f`.
- Copyright (c) 2024 Jacco Bikker.
- License: MIT; full text in `licenses/tinybvh-MIT.txt`.
- Use: `ThirdParty/tinybvh`, compiled through Veach's C ABI wrapper into the
  tinybvh WebAssembly module embedded in the release bundle.

## Adobe OpenPBR BSDF

- Upstream: https://github.com/adobe/openpbr-bsdf
- Reference: OpenPBR 1.1.1, commit `c91aad1d1ce1693e803f039d7c92c2965c4eb013`.
- Copyright 2026 Adobe.
- License: Apache-2.0; full text in `licenses/Apache-2.0.txt`.
- Use: `shaders/Materials/BSDF` is a modified Slang port; upstream lookup tables
  are repacked into `src/generated/bsdf/BSDFTables.bin`. The generated shaders and
  tables are included in the release bundle.
- Modifications: Slang/WebGPU integration, renderer-specific interfaces and BSDF
  integration, and binary packing of energy-compensation and LTC tables.
  The vendored C++ reference and test harness are not included in the npm package.

## ACES Core Transforms

- Upstream: https://github.com/aces-aswf/aces-core
- Reference: ACES 2.0 core CTL transforms.
- Copyright Contributors to the ACES Project.
- License: Apache-2.0; full text in `licenses/Apache-2.0.txt`.
- Use: `src/render/aces/ACES2.ts`, compiled into the release bundle.
- Modifications: CTL functions translated to TypeScript, CPU table generation and
  integration with Veach's tone-mapping LUT. This is a modified implementation,
  not an unmodified upstream ACES distribution.
- License/header references:
  https://github.com/aces-aswf/aces-core/blob/main/LICENSE and
  https://github.com/aces-aswf/aces-core/blob/main/lib/Lib.Academy.OutputTransform.ctl.

## Cycles procedural textures and Open Shading Language noise

- Upstream: https://github.com/blender/blender/tree/v4.5.0/intern/cycles
- Use: modified 3D-only implementations in `src/material/Procedural.ts` and
  `shaders/Materials/Procedural.slang`; the latter is compiled into the distributed WGSL.
- Cycles `kernel/svm/fractal_noise.h`, `noisetex.h`, `magic.h`, `checker.h`, and
  `util/hash.h`: Copyright 2011-2022 Blender Foundation; Apache-2.0.
  Full text in `licenses/Apache-2.0.txt`.
- Cycles `kernel/svm/noise.h`, adapted from Open Shading Language:
  Copyright 2009-2010 Sony Pictures Imageworks Inc., et al. All Rights Reserved;
  Copyright 2011-2022 Blender Foundation; BSD-3-Clause.
  Full text in `licenses/cycles-noise-BSD-3-Clause.txt`.
- Modifications: translation to TypeScript and Slang, restriction to 3D operations,
  and integration with Veach's material bytecode and interpreter. License headers
  were checked against Blender v4.5.0; the complete Blender application is not bundled.
- The lookup3 hashing algorithm is attributed to Bob Jenkins in both the upstream
  hash implementation and Veach's implementation.

## WebAssembly runtime support

- Upstream: https://github.com/emscripten-core/emscripten
- Use: generated JavaScript runtime glue and linked support routines for tinybvh.
- Emscripten notices: `licenses/emscripten.txt` (MIT / University of Illinois-NCSA,
  including upstream notices for Node.js-derived runtime portions).
- musl notices: `licenses/musl.txt`.
- LLVM runtime/support notices: `licenses/llvm-runtime.txt`.
- These texts are retained from the project's local Emscripten 6.0.13 toolchain;
  they do not imply that the compiler or all its libraries ship in the npm package.

## Separately installed and development dependencies

- `@webgpu/types`: https://github.com/gpuweb/types, BSD-3-Clause,
  Copyright 2022 WebGPU Developers. Installed separately for the public declarations;
  a copy of its notice is in `licenses/webgpu-types-BSD-3-Clause.txt`.
- `fzstd`: https://github.com/101arrowz/fzstd, MIT,
  Copyright (c) 2020 Arjun Barrett. Used by the development viewer's `.blend` loader;
  not included in the current public npm entry points. Its notice is retained in
  `licenses/fzstd-MIT.txt` for development builds that bundle it.
- Other build and test dependencies retain their own distributed licenses.
  Sample models, HDR images and Blender test assets are development/test inputs,
  are not covered by Veach's MIT license, and are excluded from the npm package.

When adding or updating a dependency, port or generated runtime, preserve its
copyright notices and update this file and the corresponding license text.
