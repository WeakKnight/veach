// C ABI over tinybvh for the web renderer.
//
// Every build returns an opaque handle to a BVH_GPU (Aila-Laine 64-byte nodes). JavaScript copies
// the node / triangle / index arrays out of the WASM heap and uploads them to WebGPU; the Slang
// traversal in shaders/RayTracing/Traversal.slang consumes exactly these layouts.

#define NO_DOUBLE_PRECISION_SUPPORT
#define NO_THREADED_BUILDS
#define NO_VOXEL_SUPPORT
#define TINYBVH_NO_SIMD
#define TINYBVH_IMPLEMENTATION
#include "tiny_bvh.h"

#include <emscripten/emscripten.h>
#include <cstdint>
#include <cstdlib>
#include <vector>

using tinybvh::BVH_GPU;
using tinybvh::bvhvec4;
using tinybvh::bvhvec4slice;

namespace
{
	enum BuildQuality : int32_t
	{
		Fast = 0,	// binned SAH
		High = 1,	// SBVH (spatial splits)
	};

	struct Handle
	{
		BVH_GPU bvh;
		std::vector<bvhvec4> orderedTris;
		bool overAABBs = false;
	};

	// Same records as BVH_GPU::orderedVerts, which tinybvh leaves empty when the root is a leaf.
	void BuildOrderedTris(Handle& handle, const bvhvec4* vertices, const uint32_t* indices, uint32_t triCount)
	{
		const auto& bvh = handle.bvh.bvh;
		handle.orderedTris.assign(size_t(bvh.idxCount) * 3, bvhvec4(0.0f));
		for (uint32_t i = 0; i < bvh.idxCount; i++)
		{
			// SBVH builds reserve slack: idxCount is the capacity and unreferenced entries are uninitialized.
			const uint32_t prim = bvh.primIdx[i];
			if (prim >= triCount)
			{
				continue;
			}
			const bvhvec4 v0 = vertices[indices[prim * 3 + 0]];
			const bvhvec4 v1 = vertices[indices[prim * 3 + 1]];
			const bvhvec4 v2 = vertices[indices[prim * 3 + 2]];
			bvhvec4* out = &handle.orderedTris[size_t(i) * 3];
			out[0] = bvhvec4(v0.x, v0.y, v0.z, tinybvh::tinybvh_as_float(prim));
			out[1] = bvhvec4(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z, 0.0f);
			out[2] = bvhvec4(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z, 0.0f);
		}
	}
} // namespace

extern "C"
{
	EMSCRIPTEN_KEEPALIVE void* tb_malloc(uint32_t bytes)
	{
		return malloc(bytes);
	}

	EMSCRIPTEN_KEEPALIVE void tb_free(void* ptr)
	{
		free(ptr);
	}

	EMSCRIPTEN_KEEPALIVE uint32_t tb_version()
	{
		return TINY_BVH_VERSION_MAJOR * 10000 + TINY_BVH_VERSION_MINOR * 100 + TINY_BVH_VERSION_SUB;
	}

	// vertices: vertexCount * 4 floats (xyz + pad), indices: triCount * 3 uints.
	// The vertex array must stay alive until the handle has been read out.
	EMSCRIPTEN_KEEPALIVE Handle* tb_build_blas(const float* vertices, uint32_t vertexCount, const uint32_t* indices, uint32_t triCount, int32_t quality)
	{
		if (triCount == 0)
		{
			return nullptr;
		}

		Handle* handle = new Handle();
		handle->bvh.settings.useSIMDifavailable = false;
		const bvhvec4slice slice(reinterpret_cast<const bvhvec4*>(vertices), vertexCount, sizeof(bvhvec4));
		if (quality == High)
		{
			handle->bvh.BuildHQ(slice, indices, triCount);
		}
		else
		{
			handle->bvh.Build(slice, indices, triCount);
		}
		BuildOrderedTris(*handle, reinterpret_cast<const bvhvec4*>(vertices), indices, triCount);
		return handle;
	}

	// aabbs: count * 8 floats, laid out as (min.xyz, pad, max.xyz, pad).
	EMSCRIPTEN_KEEPALIVE Handle* tb_build_tlas(const float* aabbs, uint32_t count)
	{
		if (count == 0)
		{
			return nullptr;
		}

		Handle* handle = new Handle();
		handle->overAABBs = true;
		handle->bvh.BuildAABB(reinterpret_cast<const bvhvec4*>(aabbs), count);
		return handle;
	}

	EMSCRIPTEN_KEEPALIVE void tb_destroy(Handle* handle)
	{
		delete handle;
	}

	EMSCRIPTEN_KEEPALIVE uint32_t tb_node_count(const Handle* handle)
	{
		return handle->bvh.usedNodes;
	}

	EMSCRIPTEN_KEEPALIVE const void* tb_nodes(const Handle* handle)
	{
		return handle->bvh.bvhNode;
	}

	// Number of primitive references; exceeds the triangle count for SBVH builds.
	EMSCRIPTEN_KEEPALIVE uint32_t tb_prim_ref_count(const Handle* handle)
	{
		return handle->bvh.bvh.idxCount;
	}

	// BLAS only: primRefCount * 3 float4 records (v0 | asfloat(primIdx), v1 - v0, v2 - v0).
	EMSCRIPTEN_KEEPALIVE const float* tb_ordered_tris(const Handle* handle)
	{
		return handle->overAABBs ? nullptr : reinterpret_cast<const float*>(handle->orderedTris.data());
	}

	// TLAS: leaf offsets index this array, which maps back to the input AABB (instance) index.
	EMSCRIPTEN_KEEPALIVE const uint32_t* tb_prim_indices(const Handle* handle)
	{
		return handle->bvh.bvh.primIdx;
	}

	EMSCRIPTEN_KEEPALIVE float tb_sah_cost(Handle* handle)
	{
		return handle->bvh.SAHCost();
	}

	// Root bounds: writes 6 floats (min.xyz, max.xyz).
	EMSCRIPTEN_KEEPALIVE void tb_bounds(const Handle* handle, float* out)
	{
		out[0] = handle->bvh.aabbMin.x;
		out[1] = handle->bvh.aabbMin.y;
		out[2] = handle->bvh.aabbMin.z;
		out[3] = handle->bvh.aabbMax.x;
		out[4] = handle->bvh.aabbMax.y;
		out[5] = handle->bvh.aabbMax.z;
	}
}
