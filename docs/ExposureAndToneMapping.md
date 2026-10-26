# Exposure and tone mapping

Exposure, local exposure and tone mapping are presentation settings (`isPresentationSetting`):
changing them never resets accumulation.

## Tone mapping

`Tonemapper.ACES2` (default) is the official ACES 2.0 Output Transform (SDR 100 nit, Rec.709
limiting, sRGB piecewise encoding).

- Ported from the aces-core CTL in `src/render/aces/ACES2.ts` (row-vector matrices, same table
  builders).
- Baked at startup (~0.2 s, cached per page) into a 64³ `rgba16float` 3D LUT of display code
  values.
- As in Unreal's `PostProcessCombineLUTs`, the LUT is indexed by `PQ(clamp(linear * 100, 0, 10000))`
  with a half-texel remap; texels decode the PQ, convert working-space linear Rec.709 to
  ACES2065-1 (Bradford, matching OCIO), and run the transform.
- `tests/aces2.test.ts` checks the port against `tests/fixtures/aces2-reference.json` from
  OpenColorIO (`python scripts/aces2-reference.py` regenerates it).

## Exposure

Histogram eye adaptation and path tracer pre-exposure.

- The path tracer writes `radiance * preExposure` (`envParams.z`) into the accumulation.
  `Renderer` fixes the pre-exposure when an accumulation starts to the
  last exposure read back from the GPU (auto) or `2^exposure` (manual). The firefly clamp applies
  to pre-exposed values.
- Every beauty frame, `AutoExposure` (`shaders/Passes/AutoExposure.slang`) builds a 64-bucket
  log2 luminance histogram of `accumulation / preExposure` (workgroup atomics, fixed-point
  weights, black pixels ignored).
- A one-thread pass then trims the low/high percentiles, clamps the average to Min/Max
  Brightness, adapts in log space (linear beyond 1.5 EV, exponential with matched slope within)
  and writes `gExposure[0] = (exposure scale, target scale, average luminance, compensation)`.
- Present multiplies by `gExposure[0].x / preExposure`.
- Manual mode runs the same pass with the white point pinned to 1 and the target forced. A new
  scene forces the target; debug views skip exposure.
- Luminances are log2 with luminance max 1 (extended EV100 range, defaults -10..20).

### Settings

- Public settings include `autoExposureMethod`,
  `autoExposureBias` + `autoExposureBiasCurve`, `autoExposureLow/HighPercent` clamped to 1..99,
  `autoExposureMin/MaxBrightness`, `histogramLogMin/Max` and `localExposure*Contrast*`.
- EV100 values assume the default lens attenuation 0.78 (EV100 = log2 luminance).
- `autoExposureLuminanceMethod` selects luminance weights;
  `localExposureFusionTargetLuminance` sets the well-exposedness target. The fusion weight sigma is 0.2.
- Curves key on the scene EV100 `log2(averageLuminance / 0.18)`; the histogram runs in Manual too
  so they stay valid.

## Local exposure

The fused fine-residual exposure fusion from the LocalExposure project, integrated like Unreal's
`LOCAL_EXPOSURE_MODE_FUSION`. It runs after eye adaptation in the same encoder on
`accumulation * gExposure[0].x / preExposure`; Present applies the multiplier to the luminance
after global exposure, before tone mapping.

Coupling with auto exposure (keep it):

- Luminance is `max(dot(rgb, weights), 2^histogramMinEV)` with the `autoExposureLuminanceMethod`
  weights the histogram also uses (Unreal's `CalculateEyeAdaptationLuminance`).
- Brackets are `lerp(6, 0, contrast)` EV, the scales multiplied by the optional contrast curves
  evaluated at the metered scene EV `log2(averageLuminance / 0.18)`.
- Pre-exposure stays global (Unreal's average local exposure is 1 for Fusion).
- The pass is skipped unless a scale is not 1, a curve is set or it is visualized.

Lightness response:

- A Z curve `L^a / (b L^(ad) + c)` fitted to the neutral response of the current tone mapper
  (`LocalExposureCurve.ts`, cached per tone mapper; `None` is a clip and fits worst), with a
  logit-warped 1024-entry inverse LUT.
- The bracket weights / lightness are baked into two 2048-entry forward tables over log2
  luminance [-40, 40] whenever the brackets change.

Graph at quarter resolution (`LocalExposure.ts`): initialize (4 samples), downsample
(`rgba16float` mips 0-2, `rgba32float` coarser), one-workgroup tail once a level fits 16x8,
weighted Laplacian reconstruct, with mips 2 -> 0 fused. Present restores the fine residual at
full resolution and inverts the target lightness (clamped to +-12 EV).
