# .blend import

Target: Blender's `tests/files/render/principled_bsdf`, judged by eye, not bit exact. Code in
`src/loaders/blend/` and `src/app/BlendSettings.ts`; tests in `tests/blend.test.ts` (need
`public/samples/blender`).

- Meshes stay in Blender object space; the instance transform is `Z_UP_TO_Y_UP · world`.
- Socket defaults are read by socket type, since `default_value` is untyped.
- Pre-4.0 Principled sockets are converted like `versioning_400`, because the references are
  rendered after it.
- Coat darkening is off and anisotropy is rescaled to Cycles' `aspect = sqrt(1 - 0.9 a)`.
- Solid Principled transmission is tinted by `sqrt(base)` per interface, like Cycles (in and out
  gives the base color); OpenPBR's zero-depth tint is per interface. Thin walls keep the base color.
- An unlinked texture Vector uses Generated coordinates from the unmodified mesh bounds; an
  unlinked Tangent is radial around object Z.
- Unsupported nodes produce warnings, which the viewer logs.
