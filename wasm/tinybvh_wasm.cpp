// C ABI over tinybvh for the web renderer.
//
// BLAS builds return a BVH8_CWBVH (Ylitie et al. 2017: 80-byte nodes of 8 quantized child boxes); the TLAS is a
// BVH_GPU (Aila-Laine 64-byte nodes) over instance bounds. JavaScript copies the node / triangle / index arrays out of
// the WASM heap and uploads them to WebGPU; the Slang traversal in shaders/RayTracing/Traversal.slang consumes exactly
// these layouts.

#define NO_DOUBLE_PRECISION_SUPPORT
#define NO_THREADED_BUILDS
#define NO_VOXEL_SUPPORT
#define TINYBVH_NO_SIMD
#define TINYBVH_IMPLEMENTATION
#include "tiny_bvh.h"

#include <emscripten/emscripten.h>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>

using tinybvh::BVH_GPU;
using tinybvh::BVH8_CWBVH;
using tinybvh::bvhvec3;
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
		BVH_GPU tlas;						// TLAS only
		BVH8_CWBVH blas;					// BLAS only
		std::vector<bvhvec4> nodes;			// BLAS: CWBVH nodes, 5 float4 each, root first
		std::vector<bvhvec4> orderedTris;	// BLAS: 3 float4 per CWBVH triangle slot
		bvhvec3 aabbMin, aabbMax;
		uint32_t primRefs = 0;
		bool overAABBs = false;
	};

	// tinybvh's CWBVHQuantExp: the smallest power of two that maps the extent into 255 steps.
	int32_t QuantExp(float extent)
	{
		if (!(extent > 0)) return -126;
		return (int32_t)std::fmin(std::fmax(std::ceil(std::log2(extent * (1.0f / 255.0f))), -126.0f), 126.0f);
	}

	// (v0 | asfloat(primIdx), v1 - v0, v2 - v0): the records the traversal tests.
	void AppendTri(Handle& handle, const bvhvec4* vertices, const uint32_t* indices, uint32_t prim)
	{
		const bvhvec4 v0 = vertices[indices[prim * 3 + 0]];
		const bvhvec4 v1 = vertices[indices[prim * 3 + 1]];
		const bvhvec4 v2 = vertices[indices[prim * 3 + 2]];
		handle.orderedTris.push_back(bvhvec4(v0.x, v0.y, v0.z, tinybvh::tinybvh_as_float(prim)));
		handle.orderedTris.push_back(bvhvec4(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z, 0.0f));
		handle.orderedTris.push_back(bvhvec4(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z, 0.0f));
	}

	// tinybvh cannot convert a tree whose root is a leaf, which happens exactly for meshes of at most 3 triangles
	// (CombineLeafs( 3 ) collapses larger ones only into interior nodes): one CWBVH node with a single leaf slot
	// spanning the mesh bounds.
	void SingleLeafNode(Handle& handle, const bvhvec4* vertices, const uint32_t* indices, uint32_t triCount)
	{
		bvhvec3 lo(1e30f), hi(-1e30f);
		for (uint32_t i = 0; i < triCount * 3; i++)
		{
			const bvhvec4 v = vertices[indices[i]];
			lo = tinybvh::tinybvh_min(lo, bvhvec3(v.x, v.y, v.z)), hi = tinybvh::tinybvh_max(hi, bvhvec3(v.x, v.y, v.z));
		}
		handle.aabbMin = lo, handle.aabbMax = hi;
		handle.nodes.assign(5, bvhvec4(0.0f));
		const int32_t e[3] = { QuantExp(hi.x - lo.x), QuantExp(hi.y - lo.y), QuantExp(hi.z - lo.z) };
		const uint8_t exyzAndImask[4] = { (uint8_t)(e[0] + 127), (uint8_t)(e[1] + 127), (uint8_t)(e[2] + 127), 0 };
		float packed;
		std::memcpy(&packed, exyzAndImask, 4);
		handle.nodes[0] = bvhvec4(lo.x, lo.y, lo.z, packed);
		uint8_t* meta = reinterpret_cast<uint8_t*>(&handle.nodes[1]) + 8;
		uint8_t* q = reinterpret_cast<uint8_t*>(&handle.nodes[2]);
		meta[0] = (uint8_t)((triCount == 1 ? 0b001 : triCount == 2 ? 0b011 : 0b111) << 5); // leaf, first triangle 0
		q[24] = q[32] = q[40] = 255; // slot 0: [0, 255] on every axis
		for (uint32_t i = 0; i < triCount; i++) AppendTri(handle, vertices, indices, i);
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
	EMSCRIPTEN_KEEPALIVE Handle* tb_build_blas(const float* vertices, uint32_t vertexCount, const uint32_t* indices, uint32_t triCount, int32_t quality)
	{
		if (triCount == 0)
		{
			return nullptr;
		}

		Handle* handle = new Handle();
		const bvhvec4* verts = reinterpret_cast<const bvhvec4*>(vertices);
		const bvhvec4slice slice(verts, vertexCount, sizeof(bvhvec4));
		if (triCount <= 3)
		{
			SingleLeafNode(*handle, verts, indices, triCount);
		}
		else
		{
			// A binary SAH (or SBVH) tree with at most 3 triangles per leaf, collapsed to 8-wide, then compressed.
			BVH8_CWBVH& cw = handle->blas;
			cw.settings.useSIMDifavailable = false;
			if (quality == High) cw.BuildHQ(slice, indices, triCount);
			else cw.Build(slice, indices, triCount);
			handle->aabbMin = cw.bvh8.bvh.aabbMin, handle->aabbMax = cw.bvh8.bvh.aabbMax;
			handle->nodes.assign(cw.bvh8Data, cw.bvh8Data + cw.usedBlocks);
			// CWBVH triangle slots (4 float4 each with CWBVH_COMPRESSED_TRIS), in order; the primitive index is the
			// last w. Leaves address them by float4 index, so slot = index / 4.
			const uint32_t slots = cw.usedTriBlocks / 4;
			handle->orderedTris.reserve(size_t(slots) * 3);
			for (uint32_t i = 0; i < slots; i++) AppendTri(*handle, verts, indices, tinybvh::tinybvh_as_uint(cw.bvh8Tris[i * 4 + 3].w));
		}
		handle->primRefs = uint32_t(handle->orderedTris.size() / 3);
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
		handle->tlas.BuildAABB(reinterpret_cast<const bvhvec4*>(aabbs), count);
		handle->aabbMin = handle->tlas.bvh.aabbMin, handle->aabbMax = handle->tlas.bvh.aabbMax;
		handle->primRefs = handle->tlas.bvh.idxCount;
		return handle;
	}

	EMSCRIPTEN_KEEPALIVE void tb_destroy(Handle* handle)
	{
		delete handle;
	}

	// Node data in float4 blocks: 4 per BVH_GPU node (TLAS), 5 per CWBVH node (BLAS).
	EMSCRIPTEN_KEEPALIVE uint32_t tb_node_blocks(const Handle* handle)
	{
		return handle->overAABBs ? handle->tlas.usedNodes * 4 : uint32_t(handle->nodes.size());
	}

	EMSCRIPTEN_KEEPALIVE const void* tb_nodes(const Handle* handle)
	{
		return handle->overAABBs ? static_cast<const void*>(handle->tlas.bvhNode) : static_cast<const void*>(handle->nodes.data());
	}

	// TLAS: instance references; BLAS: CWBVH triangle slots (SBVH builds reference some triangles more than once).
	EMSCRIPTEN_KEEPALIVE uint32_t tb_prim_ref_count(const Handle* handle)
	{
		return handle->primRefs;
	}

	// BLAS only: primRefCount * 3 float4 records (v0 | asfloat(primIdx), v1 - v0, v2 - v0).
	EMSCRIPTEN_KEEPALIVE const float* tb_ordered_tris(const Handle* handle)
	{
		return handle->overAABBs ? nullptr : reinterpret_cast<const float*>(handle->orderedTris.data());
	}

	// TLAS: leaf offsets index this array, which maps back to the input AABB (instance) index.
	EMSCRIPTEN_KEEPALIVE const uint32_t* tb_prim_indices(const Handle* handle)
	{
		return handle->tlas.bvh.primIdx;
	}

	// Root bounds: writes 6 floats (min.xyz, max.xyz).
	EMSCRIPTEN_KEEPALIVE void tb_bounds(const Handle* handle, float* out)
	{
		out[0] = handle->aabbMin.x;
		out[1] = handle->aabbMin.y;
		out[2] = handle->aabbMin.z;
		out[3] = handle->aabbMax.x;
		out[4] = handle->aabbMax.y;
		out[5] = handle->aabbMax.z;
	}
}
