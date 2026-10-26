// Blender's procedural textures (Cycles kernel/svm: noise.h, fractal_noise.h, noisetex.h, magic.h,
// checker.h), 3D only. Mirrors src/material/Procedural.ts.

// Truncated modulo, as C fmodf.
float FMod(float x, float y)
{
	return x - trunc(x / y) * y;
}

uint HashRotate(uint x, uint k)
{
	return (x << k) | (x >> (32u - k));
}

// Bob Jenkins' lookup3 final(a, b, c); returns c.
uint HashFinal(uint a, uint b, uint c)
{
	c ^= b; c -= HashRotate(b, 14u);
	a ^= c; a -= HashRotate(c, 11u);
	b ^= a; b -= HashRotate(a, 25u);
	c ^= b; c -= HashRotate(b, 16u);
	a ^= c; a -= HashRotate(c, 4u);
	b ^= a; b -= HashRotate(a, 14u);
	c ^= b; c -= HashRotate(b, 24u);
	return c;
}

uint HashUint2(uint kx, uint ky)
{
	uint init = 0xdeadbeefu + (2u << 2u) + 13u;
	return HashFinal(init + kx, init + ky, init);
}

uint HashUint3(uint kx, uint ky, uint kz)
{
	uint init = 0xdeadbeefu + (3u << 2u) + 13u;
	return HashFinal(init + kx, init + ky, init + kz);
}

// random_float3_offset: components in [100, 200].
float3 RandomOffset3(float seed)
{
	float3 h = float3(float(HashUint2(asuint(seed), asuint(0.0))), float(HashUint2(asuint(seed), asuint(1.0))), float(HashUint2(asuint(seed), asuint(2.0))));
	return 100.0 + h * (100.0 / 4294967295.0);
}

float NoiseFade(float t)
{
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float NoiseGrad3(uint hash, float x, float y, float z)
{
	uint h = hash & 15u;
	float u = h < 8u ? x : y;
	float v = h < 4u ? y : (h == 12u || h == 14u) ? x : z;
	return ((h & 1u) != 0u ? -u : u) + ((h & 2u) != 0u ? -v : v);
}

float Perlin3(float3 p)
{
	float3 i = floor(p);
	float3 f = p - i;
	uint X = asuint(int(i.x));
	uint Y = asuint(int(i.y));
	uint Z = asuint(int(i.z));
	float u = NoiseFade(f.x);
	float v = NoiseFade(f.y);
	float w = NoiseFade(f.z);
	// The corners (bit 0: x, 1: y, 2: z), fBM octaves, distortion and color channels below are
	// loops with one call site each, which keeps the noise instantiated once per material program.
	float g[8];
	[loop]
	for (uint c = 0u; c < 8u; ++c)
	{
		uint3 o = uint3(c & 1u, (c >> 1u) & 1u, c >> 2u);
		g[c] = NoiseGrad3(HashUint3(X + o.x, Y + o.y, Z + o.z), f.x - float(o.x), f.y - float(o.y), f.z - float(o.z));
	}
	float x00 = lerp(g[0], g[1], u);
	float x10 = lerp(g[2], g[3], u);
	float x01 = lerp(g[4], g[5], u);
	float x11 = lerp(g[6], g[7], u);
	return lerp(lerp(x00, x10, v), lerp(x01, x11, v), w);
}

// Signed noise in about [-1, 1], repeating every 100000 units.
float SNoise3(float3 p)
{
	float3 q = float3(FMod(p.x, 100000.0), FMod(p.y, 100000.0), FMod(p.z, 100000.0));
	q += select(abs(p) >= float3(1000000.0), float3(0.5), float3(0.0));
	return 0.982 * Perlin3(q);
}

float NoiseFbm(float3 p, float detail, float roughness, float lacunarity, bool normalize)
{
	float fscale = 1.0;
	float amp = 1.0;
	float maxamp = 0.0;
	float sum = 0.0;
	int octaves = int(detail);
	float rmd = detail - floor(detail);
	// the fractional octave runs as the loop's last iteration
	int last = rmd != 0.0 ? octaves + 1 : octaves;
	float sum2 = 0.0;
	[loop]
	for (int i = 0; i <= last; i++)
	{
		float n = SNoise3(fscale * p);
		if (i > octaves)
		{
			sum2 = sum + n * amp;
			break;
		}
		sum += n * amp;
		maxamp += amp;
		amp *= roughness;
		fscale *= lacunarity;
	}
	if (rmd != 0.0)
	{
		float a = normalize ? 0.5 * sum / maxamp + 0.5 : sum;
		float b = normalize ? 0.5 * sum2 / (maxamp + amp) + 0.5 : sum2;
		return lerp(a, b, rmd);
	}
	return normalize ? 0.5 * sum / maxamp + 0.5 : sum;
}

// Noise Texture (fBM, 3D) at scaled coordinates. params: detail, roughness, lacunarity,
// distortion. Returns (fac, color.g, color.b); color.r is fac.
float3 BlenderNoise(float3 co, float4 params, bool normalize, bool color)
{
	float detail = clamp(params.x, 0.0, 15.0);
	float roughness = max(params.y, 0.0);
	float lacunarity = params.z;
	float distortion = params.w;
	float3 p = co;
	if (distortion != 0.0)
	{
		float3 offset;
		[loop]
		for (uint k = 0u; k < 3u; ++k)
		{
			offset[k] = SNoise3(p + RandomOffset3(float(k)));
		}
		p += offset * distortion;
	}
	// fac, then color.g and color.b at offsets 3 and 4
	float3 result;
	[loop]
	for (uint k = 0u; k < (color ? 3u : 1u); ++k)
	{
		result[k] = NoiseFbm(k == 0u ? p : p + RandomOffset3(float(k + 2u)), detail, roughness, lacunarity, normalize);
	}
	return color ? result : float3(result.x);
}

// Magic Texture at scaled coordinates. Returns rgb.
float3 BlenderMagic(float3 p, uint depth, float d)
{
	const float TWO_PI = 2.0 * float.getPi();
	float px = FMod(p.x, TWO_PI);
	float py = FMod(p.y, TWO_PI);
	float pz = FMod(p.z, TWO_PI);
	float x = sin((px + py + pz) * 5.0);
	float y = cos((-px + py - pz) * 5.0);
	float z = -cos((-px - py + pz) * 5.0);
	if (depth > 0u)
	{
		x *= d;
		y *= d;
		z *= d;
		y = -cos(x - y + z) * d;
		if (depth > 1u) { x = cos(x - y - z) * d; }
		if (depth > 2u) { z = sin(-x - y - z) * d; }
		if (depth > 3u) { x = -cos(-x + y - z) * d; }
		if (depth > 4u) { y = -sin(-x + y + z) * d; }
		if (depth > 5u) { y = -cos(-x + y + z) * d; }
		if (depth > 6u) { x = cos(x + y + z) * d; }
		if (depth > 7u) { z = sin(x + y - z) * d; }
		if (depth > 8u) { x = -cos(-x - y + z) * d; }
		if (depth > 9u) { y = -sin(x - y + z) * d; }
	}
	if (d != 0.0)
	{
		x /= 2.0 * d;
		y /= 2.0 * d;
		z /= 2.0 * d;
	}
	return float3(0.5 - x, 0.5 - y, 0.5 - z);
}

// Checker Texture factor (1 = Color1) at scaled coordinates.
float BlenderChecker(float3 p)
{
	int3 i = abs(int3(floor((p + 0.000001) * 0.999999)));
	bool same = (i.x & 1) == (i.y & 1);
	return same == ((i.z & 1) == 1) ? 1.0 : 0.0;
}
