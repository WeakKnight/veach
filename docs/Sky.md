# Sky

Without an HDR, the environment is a physically based atmosphere after Hillaire 2020 (same
constants as UE / the Nan project), baked on the GPU by `AtmosphereBaker`
(`shaders/Passes/Atmosphere.slang`).

## Bake

- Once at startup: transmittance (256x64, sqrt altitude mapping) and multiple-scattering (32x32)
  `rgba32float` LUTs.
- Per sun change: a 200x200 sky-view LUT (sky rows, cosine-weighted sky irradiance, ground rows),
  the 512x256 `rgba16float` equirect map and its CDF (same layout as `buildEnvironmentCdf`, black
  rows uniform). About 1.5 ms.
- Written in place into a storage `Environment`, so bindings never change and the path tracer
  importance-samples the sky like any HDR.
- `Renderer` rebakes when the sun direction, irradiance, color or `environmentRotation` changes.

## Lighting

- The ground below the horizon is Lambertian (albedo 0.3), lit by the attenuated sun and the sky
  irradiance.
- `sunRadiance` is multiplied by the viewer-to-sun transmittance; HDR environments leave the sun
  unattenuated.
- The sun irradiance is the outer-space value (default pi) and also lights the sky, so disabling
  the sun keeps the sky.

## CPU reference

`src/render/Atmosphere.ts` is the CPU reference the shader ports. Tests run against it; keep both
in sync (a GPU readback matched it to ~0.1%, i.e. half precision). The renderer only takes
`sunTransmittance` from it.
