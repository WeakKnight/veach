// Precomputed microfacet energy compensation tables and the LTC sheen fit, all 32 entries per axis,
// packed into one 32x32x72 r32float texture (BSDF_TABLE_* slices, built by scripts/build-bsdf-tables.mjs).
// Energy entries hold raw 16-bit unorm integers, decoded here; lookups interpolate by hand.
import Common.Math;
import Materials.BSDF.BSDFCommon;
import Materials.BSDF.Fresnel;

[[vk::binding(13, 0)]] Texture3D<float> gBSDFTables;

static const int BSDF_TABLE_SIZE = 32;
static const int BSDF_TABLE_LAST = BSDF_TABLE_SIZE - 1;

// 3D tables are [ior][alpha][cos] (32 slices each), 2D tables [x][y] in one slice (y along x texels),
// the 1D table in row 0; the LTC table is [alpha][cos] with one slice per coefficient.
static const int BSDF_TABLE_IDEAL_DIELECTRIC_ENERGY_COMPLEMENT = 0;
static const int BSDF_TABLE_OPAQUE_DIELECTRIC_ENERGY_COMPLEMENT = 32;
static const int BSDF_TABLE_IDEAL_DIELECTRIC_AVERAGE_ENERGY_COMPLEMENT = 64;
static const int BSDF_TABLE_IDEAL_DIELECTRIC_REFLECTION_RATIO = 65;
static const int BSDF_TABLE_OPAQUE_DIELECTRIC_AVERAGE_ENERGY_COMPLEMENT = 66;
static const int BSDF_TABLE_IDEAL_METAL_ENERGY_COMPLEMENT = 67;
static const int BSDF_TABLE_IDEAL_METAL_AVERAGE_ENERGY_COMPLEMENT = 68;
static const int BSDF_TABLE_LTC = 69;
static const int BSDF_TABLE_SLICES = 72;

static const float TABLE_IOR_MAX = 2.5;
static const float TABLE_INV_IOR_MAX = 1.0 / TABLE_IOR_MAX;

float FetchTable(int x, int y, int slice)
{
	return gBSDFTables.Load(int4(x, y, slice, 0));
}

float FetchEnergy(int x, int y, int slice)
{
	const float INV_UNORM_ONE = 1.0 / 65535.0;
	return FetchTable(x, y, slice) * INV_UNORM_ONE;
}

float ClampExactIndex(float index)
{
	return clamp(index, 0.0, float(BSDF_TABLE_LAST));
}

float IorToExactIndex(float ior)
{
	const float INV_RANGE = 1.0 / (TABLE_IOR_MAX - 1.0);
	const int HALF = BSDF_TABLE_SIZE / 2;
	const int HALF_MINUS_ONE = HALF - 1;
	if (ior < 1.0)
	{
		float fraction = (1.0 / ior - 1.0) * INV_RANGE;
		return HALF_MINUS_ONE - fraction * HALF_MINUS_ONE;
	}
	float fraction = (ior - 1.0) * INV_RANGE;
	return HALF + fraction * HALF_MINUS_ONE;
}

float AlphaToExactIndex(float alpha)
{
	return sqrt(alpha) * BSDF_TABLE_LAST;
}

float CosToExactIndex(float cosTheta)
{
	return cosTheta * BSDF_TABLE_LAST;
}

float LookUpLinear(int slice, float exactX)
{
	float x = ClampExactIndex(exactX);
	int i0 = int(floor(x));
	int i1 = min(i0 + 1, BSDF_TABLE_LAST);
	float t = x - float(i0);
	return lerp(FetchEnergy(i0, 0, slice), FetchEnergy(i1, 0, slice), t);
}

// table[x][y]
float LookUpBilinear(int slice, float exactX, float exactY)
{
	float x = ClampExactIndex(exactX);
	float y = ClampExactIndex(exactY);
	int ix0 = int(floor(x));
	int iy0 = int(floor(y));
	int ix1 = min(ix0 + 1, BSDF_TABLE_LAST);
	int iy1 = min(iy0 + 1, BSDF_TABLE_LAST);
	float tx = x - float(ix0);
	float ty = y - float(iy0);
	float v00 = FetchEnergy(iy0, ix0, slice);
	float v01 = FetchEnergy(iy1, ix0, slice);
	float v10 = FetchEnergy(iy0, ix1, slice);
	float v11 = FetchEnergy(iy1, ix1, slice);
	return lerp(lerp(v00, v10, tx), lerp(v01, v11, tx), ty);
}

// table[x][y][z], 32 slices from firstSlice
float LookUpTrilinear(int firstSlice, float exactX, float exactY, float exactZ)
{
	float x = ClampExactIndex(exactX);
	float y = ClampExactIndex(exactY);
	float z = ClampExactIndex(exactZ);
	int ix0 = int(floor(x));
	int iy0 = int(floor(y));
	int iz0 = int(floor(z));
	int ix1 = min(ix0 + 1, BSDF_TABLE_LAST);
	int iy1 = min(iy0 + 1, BSDF_TABLE_LAST);
	int iz1 = min(iz0 + 1, BSDF_TABLE_LAST);
	float tx = x - float(ix0);
	float ty = y - float(iy0);
	float tz = z - float(iz0);
	float v000 = FetchEnergy(iz0, iy0, firstSlice + ix0);
	float v001 = FetchEnergy(iz1, iy0, firstSlice + ix0);
	float v010 = FetchEnergy(iz0, iy1, firstSlice + ix0);
	float v011 = FetchEnergy(iz1, iy1, firstSlice + ix0);
	float v100 = FetchEnergy(iz0, iy0, firstSlice + ix1);
	float v101 = FetchEnergy(iz1, iy0, firstSlice + ix1);
	float v110 = FetchEnergy(iz0, iy1, firstSlice + ix1);
	float v111 = FetchEnergy(iz1, iy1, firstSlice + ix1);
	float v00 = lerp(v000, v100, tx);
	float v01 = lerp(v001, v101, tx);
	float v10 = lerp(v010, v110, tx);
	float v11 = lerp(v011, v111, tx);
	return lerp(lerp(v00, v10, ty), lerp(v01, v11, ty), tz);
}

// The opaque tables end at TABLE_IOR_MAX; beyond it they fade out with F0.
float ExtrapolateBeyondIorMax(float tableValue, float ior)
{
	if (ior > TABLE_IOR_MAX || ior < TABLE_INV_IOR_MAX)
	{
		const float F0_MAX = F0FromIor(TABLE_IOR_MAX);
		const float INV_F0_RANGE = 1.0 / (1.0 - F0_MAX);
		float progressTowardZero = (F0FromIor(ior) - F0_MAX) * INV_F0_RANGE;
		return (1.0 - progressTowardZero) * tableValue;
	}
	return tableValue;
}

float IdealDielectricEnergyComplement(float ior, float alpha, float cosTheta)
{
	return LookUpTrilinear(BSDF_TABLE_IDEAL_DIELECTRIC_ENERGY_COMPLEMENT, IorToExactIndex(ior), AlphaToExactIndex(alpha), CosToExactIndex(cosTheta));
}

float IdealDielectricAverageEnergyComplement(float ior, float alpha)
{
	return LookUpBilinear(BSDF_TABLE_IDEAL_DIELECTRIC_AVERAGE_ENERGY_COMPLEMENT, IorToExactIndex(ior), AlphaToExactIndex(alpha));
}

float IdealDielectricReflectionRatio(float ior, float alpha)
{
	return LookUpBilinear(BSDF_TABLE_IDEAL_DIELECTRIC_REFLECTION_RATIO, IorToExactIndex(ior), AlphaToExactIndex(alpha));
}

float OpaqueDielectricEnergyComplement(float ior, float alpha, float cosTheta)
{
	float value = LookUpTrilinear(BSDF_TABLE_OPAQUE_DIELECTRIC_ENERGY_COMPLEMENT, IorToExactIndex(ior), AlphaToExactIndex(alpha), CosToExactIndex(cosTheta));
	return ExtrapolateBeyondIorMax(value, ior);
}

float OpaqueDielectricAverageEnergyComplement(float ior, float alpha)
{
	float value = LookUpBilinear(BSDF_TABLE_OPAQUE_DIELECTRIC_AVERAGE_ENERGY_COMPLEMENT, IorToExactIndex(ior), AlphaToExactIndex(alpha));
	return ExtrapolateBeyondIorMax(value, ior);
}

float IdealMetalEnergyComplement(float alpha, float cosTheta)
{
	return LookUpBilinear(BSDF_TABLE_IDEAL_METAL_ENERGY_COMPLEMENT, AlphaToExactIndex(alpha), CosToExactIndex(cosTheta));
}

float IdealMetalAverageEnergyComplement(float alpha)
{
	return LookUpLinear(BSDF_TABLE_IDEAL_METAL_AVERAGE_ENERGY_COMPLEMENT, AlphaToExactIndex(alpha));
}

// Average energy reflected by an opaque rough dielectric; exact for zero roughness.
float DielectricEnergyReflected(float ior, float alpha, float cosTheta)
{
	if (alpha == 0.0)
	{
		return FresnelDielectric(ior, cosTheta);
	}
	return 1.0 - OpaqueDielectricEnergyComplement(ior, alpha, cosTheta);
}

// Average energy complements decoded from 16 bits can be zero.
float ClampAverageEnergyComplement(float value)
{
	return max(value, 1e-12);
}

float3 FetchLTC(int row, int col)
{
	return float3(FetchTable(col, row, BSDF_TABLE_LTC), FetchTable(col, row, BSDF_TABLE_LTC + 1), FetchTable(col, row, BSDF_TABLE_LTC + 2));
}

// (a_inv, b_inv, R) of the sheen LTC for sheen roughness alpha, bilinear like Disney's SheenLTC::fetchCoeffs.
float3 SheenLTCCoefficients(float alpha, float cosTheta)
{
	float row = max(0.0, min(alpha, ONE_MINUS_EPSILON)) * float(BSDF_TABLE_LAST);
	float col = max(0.0, min(cosTheta, ONE_MINUS_EPSILON)) * float(BSDF_TABLE_LAST);
	float r = floor(row);
	float c = floor(col);
	float rf = row - r;
	float cf = col - c;
	int ri = int(r);
	int ci = int(c);
	return lerp(lerp(FetchLTC(ri, ci), FetchLTC(ri, ci + 1), cf), lerp(FetchLTC(ri + 1, ci), FetchLTC(ri + 1, ci + 1), cf), rf);
}
