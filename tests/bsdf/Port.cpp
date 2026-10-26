// Runs the Slang BSDF (BSDFHarness.slang compiled to C++) on the CPU, reading the tables from the
// same packed buffer the renderer uploads (src/generated/bsdf/BSDFTables.bin).
#include <cfloat>
#include <cstdlib>
#include <cstring>

// The Slang prelude knows no wasm platform, and wasm32 has no _Float16 (selected by FLT16_MIN).
#define SLANG_PLATFORM
#define SLANG_LINUX 1
#undef FLT16_MIN

#include "BSDFHarness.cpp"

namespace
{

constexpr uint32_t CASE_FLOATS = 96;
constexpr uint32_t RESULT_FLOATS = 32;
constexpr uint32_t TABLE_SIZE = 32;
constexpr uint32_t TABLE_SLICES = 72;

struct TableTexture final : ITexture
{
	const float* data = nullptr;

	TextureDimensions GetDimensions(int) override
	{
		TextureDimensions d;
		d.reset();
		d.width = TABLE_SIZE;
		d.height = TABLE_SIZE;
		d.depth = TABLE_SLICES;
		d.numberOfLevels = 1;
		return d;
	}

	// v = (x, y, slice, mip); out of range reads 0 like WebGPU robust access.
	void Load(const int32_t* v, void* outData, size_t dataSize) override
	{
		float value = 0.0f;
		if (v[0] >= 0 && v[0] < int32_t(TABLE_SIZE) && v[1] >= 0 && v[1] < int32_t(TABLE_SIZE) && v[2] >= 0 && v[2] < int32_t(TABLE_SLICES) && v[3] == 0)
		{
			value = data[(size_t(v[2]) * TABLE_SIZE + size_t(v[1])) * TABLE_SIZE + size_t(v[0])];
		}
		std::memcpy(outData, &value, dataSize < sizeof(value) ? dataSize : sizeof(value));
	}

	void Sample(SamplerState, const float*, void*, size_t) override { std::abort(); }
	void SampleLevel(SamplerState, const float*, float, void*, size_t) override { std::abort(); }
};

} // namespace

extern "C" void RunPort(const float* cases, float* results, int32_t count, const float* tables)
{
	TableTexture texture;
	texture.data = tables;

	GlobalParams_0 params = {};
	params.gCases_0.data = const_cast<float*>(cases);
	params.gCases_0.count = size_t(count) * CASE_FLOATS;
	params.gResults_0.data = results;
	params.gResults_0.count = size_t(count) * RESULT_FLOATS;
	params.gBSDFTables_0.texture = &texture;

	ComputeVaryingInput input = {};
	input.startGroupID = uint3{ 0, 0, 0 };
	input.endGroupID = uint3{ (uint32_t(count) + 63) / 64, 1, 1 };
	Run(&input, nullptr, &params);
}
