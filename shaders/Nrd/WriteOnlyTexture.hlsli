// Subscript stores for write-only storage textures, included by NRD.hlsli in scripts/build-nrd.mjs.
// NRD writes its outputs as `gOut[ pixelPos ] = value`. Declaring them as `WTexture2D` selects WGSL `write`
// access, which every non-r32 storage format requires, but the core module gives write-only textures no
// subscript. This set-only subscript forwards to `Store`. The build declares a texture write-only only when
// the shader never reads it: Slang 2026 reports a read through a set-only subscript as an internal error.
// Access 2 is kCoreModule_ResourceAccessWriteOnly (slang-type-system-shared.h).
__generic<T : ITexelElement, Shape : __ITextureShape, let isArray : int, let sampleCount : int, let isShadow : int, let format : int>
extension _Texture<T, Shape, isArray, 0, sampleCount, 2, isShadow, 0, format>
{
	__subscript(vector<uint, Shape.dimensions + isArray> location) -> T
	{
		[nonmutating]
		[ForceInline]
		set { this.Store(location, newValue); }
	}
}
