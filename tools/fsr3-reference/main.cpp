// Minimal native AMD FidelityFX FSR 3 reference: runs the prebuilt, signed FidelityFX SDK 1.1.4 DX12 runtime
// (amd_fidelityfx_dx12.dll, ffx-api) on inputs captured from Veach (capture.mjs) and writes its outputs, so
// compare.mjs can check Veach's WebGPU port against AMD's implementation frame by frame.
// Usage: fsr3_reference <capture-dir>
// Reads frames.txt and frameNNN.{color,depth,motion}.bin; writes frameNNN.native.bin (RGBA16F, packed rows).
#include <d3d12.h>
#include <dxgi1_6.h>
#include <wrl/client.h>

#include <ffx_api/ffx_api.h>
#include <ffx_api/ffx_upscale.h>
#include <ffx_api/dx12/ffx_api_dx12.h>

#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;

#define CHECK(expr) do { HRESULT hr_ = (expr); if (FAILED(hr_)) { std::fprintf(stderr, "%s failed: 0x%08lx (line %d)\n", #expr, (unsigned long)hr_, __LINE__); std::exit(1); } } while (0)

struct Frame {
	unsigned renderW, renderH, upscaleW, upscaleH;
	float jitterX, jitterY;
	int reset;
	float frameTimeDelta, preExposure, cameraNear, cameraFar, fovY, viewSpaceToMeters, sharpness;
};

static std::vector<unsigned char> ReadFile(const std::string& path) {
	FILE* f = std::fopen(path.c_str(), "rb");
	if (!f) { std::fprintf(stderr, "cannot open %s\n", path.c_str()); std::exit(1); }
	std::fseek(f, 0, SEEK_END); long size = std::ftell(f); std::fseek(f, 0, SEEK_SET);
	std::vector<unsigned char> data(size);
	if (std::fread(data.data(), 1, size, f) != (size_t)size) { std::fprintf(stderr, "short read %s\n", path.c_str()); std::exit(1); }
	std::fclose(f);
	return data;
}

static void WriteFile(const std::string& path, const void* data, size_t size) {
	FILE* f = std::fopen(path.c_str(), "wb");
	if (!f || std::fwrite(data, 1, size, f) != size) { std::fprintf(stderr, "cannot write %s\n", path.c_str()); std::exit(1); }
	std::fclose(f);
}

struct Context {
	ComPtr<ID3D12Device> device;
	ComPtr<ID3D12CommandQueue> queue;
	ComPtr<ID3D12CommandAllocator> allocator;
	ComPtr<ID3D12GraphicsCommandList> list;
	ComPtr<ID3D12Fence> fence;
	UINT64 fenceValue = 0;
	HANDLE event = nullptr;

	void Submit() {
		CHECK(list->Close());
		ID3D12CommandList* lists[] = { list.Get() };
		queue->ExecuteCommandLists(1, lists);
		CHECK(queue->Signal(fence.Get(), ++fenceValue));
		CHECK(fence->SetEventOnCompletion(fenceValue, event));
		WaitForSingleObject(event, INFINITE);
		CHECK(allocator->Reset());
		CHECK(list->Reset(allocator.Get(), nullptr));
	}
};

static ComPtr<ID3D12Resource> CreateTexture(Context& c, unsigned w, unsigned h, DXGI_FORMAT format, D3D12_RESOURCE_FLAGS flags, D3D12_RESOURCE_STATES state) {
	D3D12_HEAP_PROPERTIES heap = { D3D12_HEAP_TYPE_DEFAULT };
	D3D12_RESOURCE_DESC desc = {};
	desc.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D; desc.Width = w; desc.Height = h; desc.DepthOrArraySize = 1; desc.MipLevels = 1;
	desc.Format = format; desc.SampleDesc.Count = 1; desc.Flags = flags;
	ComPtr<ID3D12Resource> texture;
	CHECK(c.device->CreateCommittedResource(&heap, D3D12_HEAP_FLAG_NONE, &desc, state, nullptr, IID_PPV_ARGS(&texture)));
	return texture;
}

static ComPtr<ID3D12Resource> CreateBuffer(Context& c, UINT64 size, D3D12_HEAP_TYPE type, D3D12_RESOURCE_STATES state) {
	D3D12_HEAP_PROPERTIES heap = { type };
	D3D12_RESOURCE_DESC desc = {};
	desc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER; desc.Width = size; desc.Height = 1; desc.DepthOrArraySize = 1; desc.MipLevels = 1;
	desc.SampleDesc.Count = 1; desc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
	ComPtr<ID3D12Resource> buffer;
	CHECK(c.device->CreateCommittedResource(&heap, D3D12_HEAP_FLAG_NONE, &desc, state, nullptr, IID_PPV_ARGS(&buffer)));
	return buffer;
}

static void Barrier(Context& c, ID3D12Resource* resource, D3D12_RESOURCE_STATES before, D3D12_RESOURCE_STATES after) {
	D3D12_RESOURCE_BARRIER b = {};
	b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION; b.Transition.pResource = resource; b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
	b.Transition.StateBefore = before; b.Transition.StateAfter = after;
	c.list->ResourceBarrier(1, &b);
}

// Copies packed rows (bpp bytes per texel) into a texture in COPY_DEST state through an upload buffer.
static void Upload(Context& c, ID3D12Resource* texture, ID3D12Resource* upload, const std::vector<unsigned char>& data, unsigned w, unsigned h, unsigned bpp) {
	D3D12_RESOURCE_DESC desc = texture->GetDesc();
	D3D12_PLACED_SUBRESOURCE_FOOTPRINT footprint; UINT rows; UINT64 rowSize, total;
	c.device->GetCopyableFootprints(&desc, 0, 1, 0, &footprint, &rows, &rowSize, &total);
	if (data.size() != (size_t)w * h * bpp) { std::fprintf(stderr, "unexpected input size %zu\n", data.size()); std::exit(1); }
	unsigned char* mapped = nullptr;
	CHECK(upload->Map(0, nullptr, (void**)&mapped));
	for (unsigned y = 0; y < h; y++) std::memcpy(mapped + footprint.Offset + (size_t)y * footprint.Footprint.RowPitch, data.data() + (size_t)y * w * bpp, (size_t)w * bpp);
	upload->Unmap(0, nullptr);
	D3D12_TEXTURE_COPY_LOCATION dst = { texture, D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX }; dst.SubresourceIndex = 0;
	D3D12_TEXTURE_COPY_LOCATION src = { upload, D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT }; src.PlacedFootprint = footprint;
	c.list->CopyTextureRegion(&dst, 0, 0, 0, &src, nullptr);
}

int main(int argc, char** argv) {
	if (argc < 2) { std::fprintf(stderr, "usage: fsr3_reference <capture-dir>\n"); return 1; }
	const std::string dir = argv[1];
	std::vector<Frame> frames;
	{
		FILE* f = std::fopen((dir + "/frames.txt").c_str(), "r");
		if (!f) { std::fprintf(stderr, "cannot open frames.txt\n"); return 1; }
		Frame fr;
		while (std::fscanf(f, "%u %u %u %u %f %f %d %f %f %f %f %f %f %f", &fr.renderW, &fr.renderH, &fr.upscaleW, &fr.upscaleH, &fr.jitterX, &fr.jitterY,
			&fr.reset, &fr.frameTimeDelta, &fr.preExposure, &fr.cameraNear, &fr.cameraFar, &fr.fovY, &fr.viewSpaceToMeters, &fr.sharpness) == 14) frames.push_back(fr);
		std::fclose(f);
	}
	if (frames.empty()) { std::fprintf(stderr, "no frames\n"); return 1; }
	const Frame& first = frames[0];

	Context c;
	ComPtr<IDXGIFactory6> factory;
	CHECK(CreateDXGIFactory2(0, IID_PPV_ARGS(&factory)));
	ComPtr<IDXGIAdapter1> adapter;
	CHECK(factory->EnumAdapterByGpuPreference(0, DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE, IID_PPV_ARGS(&adapter)));
	DXGI_ADAPTER_DESC1 adapterDesc; adapter->GetDesc1(&adapterDesc);
	std::fprintf(stderr, "[fsr3-reference] adapter %ls\n", adapterDesc.Description);
	CHECK(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_12_0, IID_PPV_ARGS(&c.device)));
	D3D12_COMMAND_QUEUE_DESC queueDesc = { D3D12_COMMAND_LIST_TYPE_DIRECT };
	CHECK(c.device->CreateCommandQueue(&queueDesc, IID_PPV_ARGS(&c.queue)));
	CHECK(c.device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&c.allocator)));
	CHECK(c.device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, c.allocator.Get(), nullptr, IID_PPV_ARGS(&c.list)));
	CHECK(c.device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&c.fence)));
	c.event = CreateEvent(nullptr, FALSE, FALSE, nullptr);

	// Veach's FSR 3 context: HDR pre-exposed radiance, inverted infinite depth, automatic exposure,
	// render-resolution motion vectors without jitter.
	ffxCreateBackendDX12Desc backend = {};
	backend.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12;
	backend.device = c.device.Get();
	ffxCreateContextDescUpscale create = {};
	create.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE;
	create.header.pNext = &backend.header;
	create.flags = FFX_UPSCALE_ENABLE_HIGH_DYNAMIC_RANGE | FFX_UPSCALE_ENABLE_DEPTH_INVERTED | FFX_UPSCALE_ENABLE_DEPTH_INFINITE | FFX_UPSCALE_ENABLE_AUTO_EXPOSURE;
	create.maxRenderSize = { first.renderW, first.renderH };
	create.maxUpscaleSize = { first.upscaleW, first.upscaleH };
	ffxContext upscaler = nullptr;
	if (ffxCreateContext(&upscaler, &create.header, nullptr) != FFX_API_RETURN_OK) { std::fprintf(stderr, "ffxCreateContext failed\n"); return 1; }

	const unsigned rw = first.renderW, rh = first.renderH, uw = first.upscaleW, uh = first.upscaleH;
	auto color = CreateTexture(c, rw, rh, DXGI_FORMAT_R16G16B16A16_FLOAT, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_COPY_DEST);
	auto depth = CreateTexture(c, rw, rh, DXGI_FORMAT_R32_FLOAT, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_COPY_DEST);
	auto motion = CreateTexture(c, rw, rh, DXGI_FORMAT_R32G32_FLOAT, D3D12_RESOURCE_FLAG_NONE, D3D12_RESOURCE_STATE_COPY_DEST);
	auto output = CreateTexture(c, uw, uh, DXGI_FORMAT_R16G16B16A16_FLOAT, D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
	const UINT64 uploadSize = (UINT64)((rw * 8 + 255) & ~255u) * rh + 512;
	auto uploadColor = CreateBuffer(c, uploadSize, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
	auto uploadDepth = CreateBuffer(c, uploadSize, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
	auto uploadMotion = CreateBuffer(c, uploadSize, D3D12_HEAP_TYPE_UPLOAD, D3D12_RESOURCE_STATE_GENERIC_READ);
	D3D12_RESOURCE_DESC outputDesc = output->GetDesc();
	D3D12_PLACED_SUBRESOURCE_FOOTPRINT outFootprint; UINT outRows; UINT64 outRowSize, outTotal;
	c.device->GetCopyableFootprints(&outputDesc, 0, 1, 0, &outFootprint, &outRows, &outRowSize, &outTotal);
	auto readback = CreateBuffer(c, outTotal, D3D12_HEAP_TYPE_READBACK, D3D12_RESOURCE_STATE_COPY_DEST);

	const D3D12_RESOURCE_STATES read = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
	for (size_t i = 0; i < frames.size(); i++) {
		const Frame& f = frames[i];
		char name[64]; std::snprintf(name, sizeof(name), "%s/frame%03zu", dir.c_str(), i);
		const std::string base = name;
		if (i > 0) { Barrier(c, color.Get(), read, D3D12_RESOURCE_STATE_COPY_DEST); Barrier(c, depth.Get(), read, D3D12_RESOURCE_STATE_COPY_DEST); Barrier(c, motion.Get(), read, D3D12_RESOURCE_STATE_COPY_DEST); }
		Upload(c, color.Get(), uploadColor.Get(), ReadFile(base + ".color.bin"), rw, rh, 8);
		Upload(c, depth.Get(), uploadDepth.Get(), ReadFile(base + ".depth.bin"), rw, rh, 4);
		Upload(c, motion.Get(), uploadMotion.Get(), ReadFile(base + ".motion.bin"), rw, rh, 8);
		Barrier(c, color.Get(), D3D12_RESOURCE_STATE_COPY_DEST, read);
		Barrier(c, depth.Get(), D3D12_RESOURCE_STATE_COPY_DEST, read);
		Barrier(c, motion.Get(), D3D12_RESOURCE_STATE_COPY_DEST, read);

		ffxDispatchDescUpscale dispatch = {};
		dispatch.header.type = FFX_API_DISPATCH_DESC_TYPE_UPSCALE;
		dispatch.commandList = c.list.Get();
		dispatch.color = ffxApiGetResourceDX12(color.Get(), FFX_API_RESOURCE_STATE_COMPUTE_READ);
		dispatch.depth = ffxApiGetResourceDX12(depth.Get(), FFX_API_RESOURCE_STATE_COMPUTE_READ);
		dispatch.motionVectors = ffxApiGetResourceDX12(motion.Get(), FFX_API_RESOURCE_STATE_COMPUTE_READ);
		dispatch.exposure = ffxApiGetResourceDX12(nullptr);
		dispatch.reactive = ffxApiGetResourceDX12(nullptr);
		dispatch.transparencyAndComposition = ffxApiGetResourceDX12(nullptr);
		dispatch.output = ffxApiGetResourceDX12(output.Get(), FFX_API_RESOURCE_STATE_UNORDERED_ACCESS);
		dispatch.jitterOffset = { f.jitterX, f.jitterY };
		dispatch.motionVectorScale = { 1.0f, 1.0f };
		dispatch.renderSize = { f.renderW, f.renderH };
		dispatch.upscaleSize = { f.upscaleW, f.upscaleH };
		dispatch.enableSharpening = f.sharpness > 0.0f;
		dispatch.sharpness = f.sharpness;
		dispatch.frameTimeDelta = f.frameTimeDelta;
		dispatch.preExposure = f.preExposure;
		dispatch.reset = f.reset != 0;
		dispatch.cameraNear = f.cameraNear;
		dispatch.cameraFar = f.cameraFar;
		dispatch.cameraFovAngleVertical = f.fovY;
		dispatch.viewSpaceToMetersFactor = f.viewSpaceToMeters;
		dispatch.flags = 0;
		if (ffxDispatch(&upscaler, &dispatch.header) != FFX_API_RETURN_OK) { std::fprintf(stderr, "ffxDispatch failed (frame %zu)\n", i); return 1; }

		Barrier(c, output.Get(), D3D12_RESOURCE_STATE_UNORDERED_ACCESS, D3D12_RESOURCE_STATE_COPY_SOURCE);
		D3D12_TEXTURE_COPY_LOCATION src = { output.Get(), D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX }; src.SubresourceIndex = 0;
		D3D12_TEXTURE_COPY_LOCATION dst = { readback.Get(), D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT }; dst.PlacedFootprint = outFootprint;
		c.list->CopyTextureRegion(&dst, 0, 0, 0, &src, nullptr);
		Barrier(c, output.Get(), D3D12_RESOURCE_STATE_COPY_SOURCE, D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
		c.Submit();

		std::vector<unsigned char> packed((size_t)uw * uh * 8);
		unsigned char* mapped = nullptr;
		D3D12_RANGE range = { 0, (SIZE_T)outTotal };
		CHECK(readback->Map(0, &range, (void**)&mapped));
		for (unsigned y = 0; y < uh; y++) std::memcpy(packed.data() + (size_t)y * uw * 8, mapped + outFootprint.Offset + (size_t)y * outFootprint.Footprint.RowPitch, (size_t)uw * 8);
		D3D12_RANGE none = { 0, 0 };
		readback->Unmap(0, &none);
		WriteFile(base + ".native.bin", packed.data(), packed.size());
	}
	ffxDestroyContext(&upscaler, nullptr);
	CloseHandle(c.event);
	std::fprintf(stderr, "[fsr3-reference] %zu frames -> %s/frameNNN.native.bin\n", frames.size(), dir.c_str());
	return 0;
}
