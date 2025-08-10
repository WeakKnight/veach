#import "utils.wgsl"

struct Entity 
{
    transform : mat4x4<f32>;
}

struct Camera
{
    view : mat4x4<f32>;
    projection : mat4x4<f32>;
}

@group(0) @binding(0) var<storage, read_write> gEntityList : array<Entity>;
@group(0) @binding(1) var<storage, read_write> gEntityCount : u32;
@group(0) @binding(2) var<storage, read_write> gCamera : Camera;

@compute @workgroup_size(1, 1, 1)
fn entry_point(@builtin(local_invocation_id) local_id: vec3<u32>,
@builtin(local_invocation_index) local_index: u32,
@builtin(global_invocation_id) global_id: vec3<u32>) 
{
    var entity_count: u32 = 0u;

    {
        let entity: Entity = Entity(look_at(vec3<f32>(0.0f, 0.0f, 0.0f), vec3<f32>(0.0f, 0.0f, 0.0f), vec3<f32>(0.0f, 0.0f, 0.0f)));
        gEntityList[entity_count] = entity;
        entity_count = entity_count + 1u;
    }
}