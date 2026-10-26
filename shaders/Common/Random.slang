// Counter-based random sequence (ported from Legacy/Source/XPU/Public/RandomSequence.h).

// https://github.com/skeeto/hash-prospector
uint StrongIntegerHash(uint x)
{
	x ^= x >> 16;
	x *= 0xa812d533u;
	x ^= x >> 15;
	x *= 0xb278e4adu;
	x ^= x >> 17;
	return x;
}

struct RandomSequence
{
	uint seed;

	__init(uint2 pixel, uint timeSeed)
	{
		seed = StrongIntegerHash(pixel.x + pixel.y * 65536u + StrongIntegerHash(timeSeed));
	}

	__init(uint positionSeed, uint timeSeed)
	{
		seed = StrongIntegerHash(positionSeed + StrongIntegerHash(timeSeed));
	}

	[mutating]
	float Next()
	{
		seed += 1u;
		// low 24 bits -> [0, 1)
		return float(StrongIntegerHash(seed) & 0xFFFFFFu) * 5.96046447754e-08;
	}

	[mutating]
	float2 Next2D()
	{
		float x = Next();
		float y = Next();
		return float2(x, y);
	}
};
