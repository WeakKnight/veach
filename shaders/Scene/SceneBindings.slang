// Resource bindings of the scene bind group (group 0). Mirrors src/render/PathTracer.ts.
// WebGPU only guarantees 8 storage buffers per shader stage: 7 are used here, one is left for the pass.
import Scene.SceneTypes;

[[vk::binding(0, 0)]] ConstantBuffer<FrameUniforms> gFrame;
[[vk::binding(1, 0)]] StructuredBuffer<BVHNode> gNodes;			// TLAS at 0, then every BLAS
[[vk::binding(2, 0)]] StructuredBuffer<float4> gTris;			// BVH-ordered triangles: v0|primIdx, e1, e2
[[vk::binding(3, 0)]] StructuredBuffer<Instance> gInstances;
[[vk::binding(4, 0)]] StructuredBuffer<Vertex> gVertices;
[[vk::binding(5, 0)]] StructuredBuffer<uint> gIndices;			// mesh indices, then TLAS prim indices
[[vk::binding(6, 0)]] StructuredBuffer<uint4> gMaterialData;		// material headers, textures, constants, bytecode
[[vk::binding(7, 0)]] StructuredBuffer<EmissiveTriangle> gLights;
[[vk::binding(8, 0)]] SamplerState gLinearSampler;
[[vk::binding(9, 0)]] Texture2D<float4> gEnvMap;
[[vk::binding(10, 0)]] Texture2D<float> gEnvCdf;				// rows 0..H-1 conditional, row H marginal
[[vk::binding(11, 0)]] Texture2D<float4> gVTPhysical;			// virtual texture page cache (bordered pages)
[[vk::binding(12, 0)]] Texture2D<uint> gVTPageTable;			// all page table entries of all virtual textures
// binding 13: gBSDFTables (Materials/BSDF/EnergyTables.slang, kept there so the BSDF builds standalone)
