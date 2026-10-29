import Scene.SceneTypes;
import Scene.SceneBindings;
import Common.Random;

static const float PRIMARY_NEAR = 1e-4;

float2 PrimaryCameraJitter()
{
	RandomSequence rng = RandomSequence(0x56495342u, gFrame.frame.w);
	return rng.Next2D();
}

// Invert the actual ray basis, including host off-axis and affine camera transforms.
float3 PrimaryCameraPosition(float3 world)
{
	float3 r = gFrame.cameraRight.xyz, u = gFrame.cameraUp.xyz, f = gFrame.cameraForward.xyz;
	float3 p = world - gFrame.cameraPosition.xyz;
	float invDet = rcp(dot(r, cross(u, f)));
	float3 q = float3(dot(p, cross(u, f)), dot(p, cross(f, r)), dot(p, cross(r, u))) * invDet;
	float2 shift = (PrimaryCameraJitter() - 0.5) * float2(2.0, -2.0) / float2(gFrame.frame.xy);
	q.xy -= shift * q.z;
	// Uniformly scale clip coordinates so depth is world distance along the image
	// plane normal, even for a scaled/sheared host camera. xy/w stays unchanged.
	float3 planeNormal = cross(r, u);
	return q * (abs(dot(f, planeNormal)) / length(planeNormal));
}

float PrimaryPlane(float3 p, uint plane)
{
	if (plane == 0u) return p.x + p.z;
	if (plane == 1u) return p.z - p.x;
	if (plane == 2u) return p.y + p.z;
	if (plane == 3u) return p.z - p.y;
	if (plane == 4u) return p.z;
	return PRIMARY_NEAR - p.z;
}
