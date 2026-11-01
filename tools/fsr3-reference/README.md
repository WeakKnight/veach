# FSR 3 reference: Veach's WebGPU port against AMD's DX12 runtime

A minimal native program that runs the prebuilt, signed FidelityFX SDK 1.1.4 DX12 runtime
(`amd_fidelityfx_dx12.dll`, ffx-api) on inputs captured from Veach, to check that the WebGPU port in
`src/render/fsr3` produces nearly the same output for the same input (docs/Fsr3.md, Validation).

Windows, Visual Studio 2022, CMake, a D3D12 GPU, and the SDK download (`FFX_SDK`, default
`C:/Users/Administrator/Downloads/FidelityFX-SDK-v1.1.4`).

```sh
npm run dev                                                    # port 5173, with public/samples
node tools/fsr3-reference/capture.mjs .tools/fsr3-capture 24   # inputs, dispatches, WebGPU outputs
cmake -S tools/fsr3-reference -B .tools/fsr3-reference-build -G "Visual Studio 17 2022" -A x64
cmake --build .tools/fsr3-reference-build --config Release     # copies amd_fidelityfx_dx12.dll next to the exe
.tools/fsr3-reference-build/Release/fsr3_reference.exe .tools/fsr3-capture
node tools/fsr3-reference/compare.mjs .tools/fsr3-capture      # per-frame PSNR; worst.png
```

`capture.mjs` takes an optional viewer query (default DamagedHelmet, realtime) and records, per frame:
`frameNNN.color.bin` (RGBA16F), `.depth.bin` (R32F), `.motion.bin` (RG32F), `.webgpu.bin` (Veach's output, RGBA16F),
packed rows, and `frames.txt` / `frames.json` with each dispatch description. It restarts Veach's FidelityFX context
and resets the history before the first captured frame, as a new native context does.
`fsr3_reference.exe` creates the context with Veach's flags (HDR, inverted infinite depth, auto exposure) and writes
`frameNNN.native.bin`. `compare.mjs` prints per-frame PSNR of `x / (1 + x)` tone-mapped colors and relative
luminance errors, and writes `worst.png` (native | WebGPU | difference x8).
