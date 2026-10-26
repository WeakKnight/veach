// Runs the upstream reference BSDF (ThirdParty/openpbr-bsdf, C++ with GLM and its built-in tables)
// on the case layout of BSDFHarness.slang.
#include <glm/glm.hpp>

#include "openpbr.h"

#include <cstdint>

namespace
{

constexpr int CASE_FLOATS = 96;
constexpr int RESULT_FLOATS = 32;

struct Reader
{
	const float* p;

	float Float() { return *p++; }
	glm::vec2 Float2()
	{
		const float x = Float();
		return glm::vec2(x, Float());
	}
	glm::vec3 Float3()
	{
		const float x = Float();
		const float y = Float();
		return glm::vec3(x, y, Float());
	}
	OpenPBR_Basis Basis()
	{
		OpenPBR_Basis b;
		b.t = Float3();
		b.b = Float3();
		b.n = Float3();
		return b;
	}
};

struct Writer
{
	float* p;

	void Float(float v) { *p++ = v; }
	void Float3(const glm::vec3& v)
	{
		Float(v.x);
		Float(v.y);
		Float(v.z);
	}
};

void RunCase(const float* c, float* out)
{
	Reader r{ c };
	OpenPBR_ResolvedInputs i;
	i.base_weight = r.Float();
	i.base_color = r.Float3();
	i.base_diffuse_roughness = r.Float();
	i.base_metalness = r.Float();
	i.subsurface_weight = r.Float();
	i.subsurface_color = r.Float3();
	i.subsurface_radius = r.Float();
	i.subsurface_radius_scale = r.Float3();
	i.subsurface_scatter_anisotropy = r.Float();
	i.specular_weight = r.Float();
	i.specular_color = r.Float3();
	i.specular_roughness = r.Float();
	i.specular_roughness_anisotropy = r.Float();
	i.specular_ior = r.Float();
	i.specular_anisotropy_rotation_cos_sin = r.Float2();
	i.coat_weight = r.Float();
	i.coat_color = r.Float3();
	i.coat_roughness = r.Float();
	i.coat_roughness_anisotropy = r.Float();
	i.coat_ior = r.Float();
	i.coat_darkening = r.Float();
	i.coat_anisotropy_rotation_cos_sin = r.Float2();
	i.fuzz_weight = r.Float();
	i.fuzz_color = r.Float3();
	i.fuzz_roughness = r.Float();
	i.transmission_weight = r.Float();
	i.transmission_color = r.Float3();
	i.transmission_depth = r.Float();
	i.transmission_scatter = r.Float3();
	i.transmission_scatter_anisotropy = r.Float();
	i.transmission_dispersion_scale = r.Float();
	i.transmission_dispersion_abbe_number = r.Float();
	i.thin_film_weight = r.Float();
	i.thin_film_thickness = r.Float();
	i.thin_film_ior = r.Float();
	i.emission_luminance = r.Float();
	i.emission_color = r.Float3();
	i.geometry_opacity = r.Float();
	i.geometry_thin_walled = r.Float() != 0.0f;
	i.geometry_basis = r.Basis();
	i.geometry_coat_basis = r.Basis();
	const glm::vec3 wo = r.Float3();
	const glm::vec3 wi = r.Float3();
	const glm::vec3 u = r.Float3();
	const glm::vec3 throughput = r.Float3();
	const glm::vec3 wavelengths = r.Float3();
	const float exteriorIor = r.Float();

	const OpenPBR_PreparedBsdf bsdf = openpbr_prepare(i, throughput, wavelengths, exteriorIor, wo);
	const OpenPBR_DiffuseSpecular f = openpbr_eval(bsdf, wi);
	const float pdf = openpbr_pdf(bsdf, wi);
	glm::vec3 sampledWi(0.0f);
	OpenPBR_DiffuseSpecular weight;
	weight.diffuse = weight.specular = glm::vec3(0.0f);
	float sampledPdf = 0.0f;
	OpenPBR_BsdfLobeType type = OpenPBR_BsdfLobeTypeNone;
	openpbr_sample(bsdf, u, sampledWi, weight, sampledPdf, type);
	const bool valid = sampledPdf > 0.0f;

	Writer w{ out };
	w.Float3(f.diffuse);
	w.Float3(f.specular);
	w.Float(pdf);
	w.Float3(valid ? sampledWi : glm::vec3(0.0f));
	w.Float3(valid ? weight.diffuse : glm::vec3(0.0f));
	w.Float3(valid ? weight.specular : glm::vec3(0.0f));
	w.Float(valid ? sampledPdf : 0.0f);
	w.Float(valid ? float(type) : 0.0f);
	w.Float3(bsdf.emission);
	w.Float3(bsdf.volume.extinction_coefficient);
	w.Float3(bsdf.volume.albedo);
	w.Float(bsdf.volume.anisotropy);
	w.Float(openpbr_needs_rgb_wavelengths(i) ? 1.0f : 0.0f);
	for (int k = 29; k < RESULT_FLOATS; ++k) // 29, 30: port-only conditioning info
	{
		w.Float(0.0f);
	}
}

} // namespace

extern "C" void RunReference(const float* cases, float* results, int32_t count)
{
	for (int32_t n = 0; n < count; ++n)
	{
		RunCase(cases + n * CASE_FLOATS, results + n * RESULT_FLOATS);
	}
}
