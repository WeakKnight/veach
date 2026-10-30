// C ABI over the NRD runtime library for Emscripten (scripts/build-nrd.mjs).
// NRD itself is API-agnostic: it reports pipelines, texture pools and per-frame dispatches.
// Shaders are compiled separately to WGSL; this module embeds no shader blobs.
// Each context owns one NRD instance; its denoisers use identifiers 0..n-1. Contexts may coexist.
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "NRD.h"

extern "C" {

namespace
{
struct Context
{
	nrd::Instance* instance = nullptr;
	std::vector<nrd::Identifier> identifiers;
	std::string json;
	std::vector<uint32_t> dispatches;
	nrd::CommonSettings common = {};
	nrd::ReblurSettings reblur = {};
};

void Append(std::string& json, const char* format, ...) __attribute__((format(printf, 2, 3)));
void Append(std::string& json, const char* format, ...)
{
	char buffer[512];
	va_list args;
	va_start(args, format);
	int n = vsnprintf(buffer, sizeof(buffer), format, args);
	va_end(args);
	if (n > 0) json.append(buffer, size_t(n) < sizeof(buffer) ? size_t(n) : sizeof(buffer) - 1);
}
}

uint32_t nrd_version() { return NRD_VERSION_MAJOR * 10000 + NRD_VERSION_MINOR * 100 + NRD_VERSION_BUILD; }

// Returns a context, or 0 when NRD rejects the denoisers (nrd::Denoiser values, identifier = index).
Context* nrd_create(const uint32_t* denoisers, uint32_t count)
{
	std::vector<nrd::DenoiserDesc> descs(count);
	Context* context = new Context();
	for (uint32_t i = 0; i < count; i++)
	{
		descs[i] = {nrd::Identifier(i), nrd::Denoiser(denoisers[i])};
		context->identifiers.push_back(nrd::Identifier(i));
	}
	nrd::InstanceCreationDesc creation = {};
	creation.denoisers = descs.data();
	creation.denoisersNum = count;
	if (nrd::CreateInstance(creation, context->instance) != nrd::Result::SUCCESS)
	{
		delete context;
		return nullptr;
	}
	return context;
}

void nrd_destroy(Context* context)
{
	if (!context) return;
	nrd::DestroyInstance(*context->instance);
	delete context;
}

// JSON description of pipelines, pools and samplers. Valid until the next call.
const char* nrd_instance_desc(Context* context)
{
	std::string& json = context->json;
	json.clear();
	const nrd::LibraryDesc& library = *nrd::GetLibraryDesc();
	const nrd::InstanceDesc& desc = *nrd::GetInstanceDesc(*context->instance);
	Append(json, "{\"normalEncoding\":%u,\"roughnessEncoding\":%u,\"constantBufferMaxDataSize\":%u,", uint32_t(library.normalEncoding), uint32_t(library.roughnessEncoding), desc.constantBufferMaxDataSize);
	Append(json, "\"constantBufferSpace\":%u,\"resourcesSpace\":%u,\"constantBufferRegister\":%u,", desc.constantBufferAndSamplersSpaceIndex, desc.resourcesSpaceIndex, desc.constantBufferRegisterIndex);
	Append(json, "\"samplers\":[");
	for (uint32_t i = 0; i < desc.samplersNum; i++) Append(json, "%s%u", i ? "," : "", uint32_t(desc.samplers[i]));
	Append(json, "],\"permanentPool\":[");
	for (uint32_t i = 0; i < desc.permanentPoolSize; i++) Append(json, "%s[%u,%u]", i ? "," : "", uint32_t(desc.permanentPool[i].format), uint32_t(desc.permanentPool[i].downsampleFactor));
	Append(json, "],\"transientPool\":[");
	for (uint32_t i = 0; i < desc.transientPoolSize; i++) Append(json, "%s[%u,%u]", i ? "," : "", uint32_t(desc.transientPool[i].format), uint32_t(desc.transientPool[i].downsampleFactor));
	Append(json, "],\"pipelines\":[");
	for (uint32_t i = 0; i < desc.pipelinesNum; i++)
	{
		const nrd::PipelineDesc& pipeline = desc.pipelines[i];
		Append(json, "%s{\"shader\":\"%s\",\"hasConstantData\":%s,\"ranges\":[", i ? "," : "", pipeline.shaderIdentifier, pipeline.hasConstantData ? "true" : "false");
		for (uint32_t r = 0; r < pipeline.resourceRangesNum; r++)
			Append(json, "%s[%u,%u]", r ? "," : "", uint32_t(pipeline.resourceRanges[r].descriptorType), pipeline.resourceRanges[r].descriptorsNum);
		Append(json, "]}");
	}
	Append(json, "]}");
	return json.c_str();
}

// Column-major matrices: viewToClip, viewToClipPrev, worldToView, worldToViewPrev (64 floats).
// params: mvScale xyz, jitter xy, jitterPrev xy, denoisingRange, disocclusionThreshold, viewZScale, timeDelta.
// ints: width, height, widthPrev, heightPrev, frameIndex, accumulationMode, enableValidation.
uint32_t nrd_set_common(Context* context, const float* matrices, const float* params, const uint32_t* ints)
{
	nrd::CommonSettings& c = context->common;
	memcpy(c.viewToClipMatrix, matrices, 64);
	memcpy(c.viewToClipMatrixPrev, matrices + 16, 64);
	memcpy(c.worldToViewMatrix, matrices + 32, 64);
	memcpy(c.worldToViewMatrixPrev, matrices + 48, 64);
	c.motionVectorScale[0] = params[0];
	c.motionVectorScale[1] = params[1];
	c.motionVectorScale[2] = params[2];
	c.cameraJitter[0] = params[3];
	c.cameraJitter[1] = params[4];
	c.cameraJitterPrev[0] = params[5];
	c.cameraJitterPrev[1] = params[6];
	c.denoisingRange = params[7];
	c.disocclusionThreshold = params[8];
	c.viewZScale = params[9];
	c.timeDeltaBetweenFrames = params[10];
	c.resourceSize[0] = c.rectSize[0] = uint16_t(ints[0]);
	c.resourceSize[1] = c.rectSize[1] = uint16_t(ints[1]);
	c.resourceSizePrev[0] = c.rectSizePrev[0] = uint16_t(ints[2]);
	c.resourceSizePrev[1] = c.rectSizePrev[1] = uint16_t(ints[3]);
	c.frameIndex = ints[4];
	c.accumulationMode = nrd::AccumulationMode(ints[5]);
	c.enableValidation = ints[6] != 0;
	return uint32_t(nrd::SetCommonSettings(*context->instance, c));
}

// floats: hit distance A B C, fastHistoryClampingSigmaScale, diffuse/specular prepass radius,
// minBlurRadius, maxBlurRadius, lobeAngleFraction, roughnessFraction, planeDistanceSensitivity.
// ints: maxAccumulatedFrameNum, maxFastAccumulatedFrameNum, maxStabilizedFrameNum, historyFixFrameNum,
// checkerboardMode, hitDistanceReconstructionMode, enableAntiFirefly.
// Applied to every denoiser of the context (all are REBLUR).
uint32_t nrd_set_reblur(Context* context, const float* floats, const uint32_t* ints)
{
	nrd::ReblurSettings& r = context->reblur;
	r.hitDistanceParameters.A = floats[0];
	r.hitDistanceParameters.B = floats[1];
	r.hitDistanceParameters.C = floats[2];
	r.fastHistoryClampingSigmaScale = floats[3];
	r.diffusePrepassBlurRadius = floats[4];
	r.specularPrepassBlurRadius = floats[5];
	r.minBlurRadius = floats[6];
	r.maxBlurRadius = floats[7];
	r.lobeAngleFraction = floats[8];
	r.roughnessFraction = floats[9];
	r.planeDistanceSensitivity = floats[10];
	r.maxAccumulatedFrameNum = ints[0];
	r.maxFastAccumulatedFrameNum = ints[1];
	r.maxStabilizedFrameNum = ints[2];
	r.historyFixFrameNum = ints[3];
	r.checkerboardMode = nrd::CheckerboardMode(ints[4]);
	r.hitDistanceReconstructionMode = nrd::HitDistanceReconstructionMode(ints[5]);
	r.enableAntiFirefly = ints[6] != 0;
	for (nrd::Identifier identifier : context->identifiers)
	{
		nrd::Result result = nrd::SetDenoiserSettings(*context->instance, identifier, &r);
		if (result != nrd::Result::SUCCESS) return uint32_t(result);
	}
	return 0;
}

// Flattened dispatches as u32 words: count, then per dispatch
// [pipelineIndex, gridWidth, gridHeight, resourcesNum, constantBytes, name pointer, constantWords...,
// (descriptorType, resourceType, indexInPool) * resourcesNum]. Names are static strings.
// Returns a pointer to the words, or 0 on failure. Valid until the next call.
const uint32_t* nrd_dispatches(Context* context)
{
	std::vector<uint32_t>& list = context->dispatches;
	list.clear();
	const nrd::DispatchDesc* dispatches = nullptr;
	uint32_t count = 0;
	if (nrd::GetComputeDispatches(*context->instance, context->identifiers.data(), uint32_t(context->identifiers.size()), dispatches, count) != nrd::Result::SUCCESS) return nullptr;
	list.push_back(count);
	for (uint32_t i = 0; i < count; i++)
	{
		const nrd::DispatchDesc& d = dispatches[i];
		list.insert(list.end(), {uint32_t(d.pipelineIndex), uint32_t(d.gridWidth), uint32_t(d.gridHeight), d.resourcesNum, d.constantBufferDataSize, uint32_t(uintptr_t(d.name))});
		size_t words = (d.constantBufferDataSize + 3) / 4, offset = list.size();
		list.resize(offset + words, 0);
		if (d.constantBufferDataSize) memcpy(list.data() + offset, d.constantBufferData, d.constantBufferDataSize);
		for (uint32_t r = 0; r < d.resourcesNum; r++)
			list.insert(list.end(), {uint32_t(d.resources[r].descriptorType), uint32_t(d.resources[r].type), uint32_t(d.resources[r].indexInPool)});
	}
	return list.data();
}

void* nrd_malloc(uint32_t bytes) { return malloc(bytes); }
void nrd_free(void* pointer) { free(pointer); }

}
