# BSDF

`shaders/Materials/BSDF` is a Slang-native port of adobe/openpbr-bsdf (OpenPBR 1.1.1), Veach's
only BSDF: fuzz over coat over a base of six lobes (specular, dielectric / metal multiple
scattering, EON diffuse, thin-wall specular / diffuse transmission), energy-compensated by tables.

## API

World space: `BSDF(inputs, wo, throughput, wavelengths, exteriorIor)`, `Eval` (f·|cos| as
`DiffuseSpecular`), `Pdf`, `Sample(float3 u)`, plus `emission` and the interior `volume`.

## Behavior

- No delta lobes (alpha >= 1e-6). Vertices whose active lobes are all below
  `NEAR_SPECULAR_ALPHA` skip NEE, and the next light hit (including the sun disc) gets MIS
  weight 1.
- Zero-weight lobes and zero-presence coat / fuzz are skipped (exact).
- glTF metallic-roughness imports set `specularDielectricOnly`: specular weight/color still
  control the dielectric base, but do not darken or tint the metal lobe. Native OpenPBR
  inputs default to false and retain the reference behavior. Both metal single and multiple
  scattering, including coat energy compensation, use the same resolved metal controls.
- glTF is mapped to OpenPBR in `src/material/Lower.ts`. The shading normal is unflipped and bent
  to the viewer's side of the face; the basis tangent is the program's `geometry_tangent`
  (anisotropy rotation is applied to it, the BSDF rotation stays (1, 0)).
- Media only absorb: a transmission into a non-thin-walled surface (`geometry_thin_walled` unless
  KHR_materials_volume thickness > 0) sets the path's absorption, applied per segment with
  Beer-Lambert.

## Tables

Built by `npm run build:bsdf-tables` from the vendored data into one 32x32x72 `r32float`
texture: slices 0-31 ideal dielectric, 32-63 opaque dielectric, 64-68 2D/1D tables, 69-71 LTC.

## Compile size

On Windows, Dawn compiles WGSL through HLSL and DXC, which inline every call: each call site
instantiates the whole callee, and the layers multiply. Pipeline compile time grows with that
inlined size, so keep the call structure flat (the path tracer went from ~160 s to ~7 s on a
cold Chrome cache by following these):

- The layers (`BaseLobe`, `CoatLobe`, `FuzzLobe`) implement `ILayer`: `SampleLobe` picks a lobe
  and direction, `EvalPdf` evaluates value and pdf over all lobes in one pass. Their `Sample`,
  `Eval` and `Pdf` are built on these, like Cycles' sample-then-`_surface_shader_bsdf_eval_mis`.
- The sampled lobe keeps the value and pdf it computed (`SampledLobe`, Cycles' `skip_sc`); only
  the other lobes are evaluated at its direction. Re-evaluating a near-specular lobe at a grazing
  sample of its own loses its pdf to half-vector rounding but not its value (weights of 1e15).
- `BaseLobe.EvalPdf` loops over the lobes with `[loop]` and dispatches through one switch with a
  case per lobe; so do the specular lobe's dispersion channels. Unrolling instantiates every case
  per iteration.
- Callers that need both value and pdf use `BSDF.EvalPdf` (NEE does).
- `NextEventEstimation` loops over the light sources with one BSDF evaluation and one shadow ray.

Check with the fully inlined size of the entry point (callees counted once per call site), not
the WGSL size.

## Tests

`tests/bsdf.test.ts` runs the port (Slang -> C++) and the upstream C++ in one wasm harness on
random cases per feature family (eval, pdf, sample, volume, emission) and white furnaces. After
changing `shaders/Materials/BSDF`, `shaders/Common` or `tests/bsdf`, run
`npm run build:bsdf-harness` (a source hash test fails otherwise).
The harness compiles in `.tools/bsdf-harness` and is copied into `tests/generated/bsdf` only
after compilation succeeds, keeping intermediate writes out of the watched test directory.
