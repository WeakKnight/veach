#import "utils.wgsl"

struct Entity 
{
    position: vec3<f32>;
    id: u32;

    rotation: vec4<f32>;

    scale: vec3<f32>;
    layer: u32;
}

struct Camera
{
    focalLength : f32;
    frameHeight : f32;
    screenWidth : f32;
    screenHeight : f32;
}

struct Shape
{
    shapeType: u32;
    shapeFloatParam0: f32;
    shapeFloatParam1: f32;
    shapeFloatParam2: f32;

    shapeVectorParam0: vec4<f32>;

    shapeVectorParam1: vec4<f32>;

    shapeVectorParam2: vec4<f32>;
}

fn make_entity(id:u32, pos: vec3<f32>) -> Entity
{
    let entity: Entity;
    entity.position = pos;
    entity.rotation = vec4<f32>(0.0f, 0.0f, 0.0f, 1.0f);
    entity.id = id;
    entity.scale = vec3<f32>(1.0f);
    entity.layer = ~0u;
    return entity;
}

fn make_box_shape_component(size: vec3<f32>)
{
    let shape: Shape;
    shape.shapeType = 0u;
    shape.shapeFloatParam0 = size.x;
    shape.shapeFloatParam1 = size.y;
    shape.shapeFloatParam2 = size.z;
    return shape;
}

const CameraComponentMask: u32 = 0u;
const ShapeComponentMask: u32 = 1u;

@group(0) @binding(0) var<storage, read_write> gEntityList : array<Entity>;
@group(0) @binding(1) var<storage, read_write> gEntityCount : u32;
@group(0) @binding(2) var<storage, read_write> gComponentMaskList : array<u32>;
@group(0) @binding(3) var<storage, read_write> gCameraList : array<Camera>;
@group(0) @binding(4) var<storage, read_write> gShapeList : array<Shape>;

@compute @workgroup_size(1, 1, 1)
fn entry_point(@builtin(local_invocation_id) local_id: vec3<u32>,
@builtin(local_invocation_index) local_index: u32,
@builtin(global_invocation_id) global_id: vec3<u32>) 
{
    var entity_count: u32 = 0u;

    {
        let entityId = entity_count;
        let entity: Entity = make_entity(entityId, vec3f(0.0f));
        gEntityList[entityId] = entity;
        
        var compMask = 0u;
        {
            let shapeComponent:Shape = make_box_shape_component(vec3<f32>(2.0f, 2.0f, 2.0f));
            gShapeList[entityId] = shapeComponent;
            compMask |= (1u << ShapeComponentMask);
        }
        gComponentMaskList[entityId] = compMask;

        entity_count = entity_count + 1u;
    }

    {
        let entityId = entity_count;
        let cameraEntity: Entity = make_entity(entityId, vec3f(0.0f, 0.0f, -10.0f));
        gEntityList[entityId] = cameraEntity;

        var compMask = 0u;
        {
            let cameraComponent: Camera = Camera(24.0f, 24.0f, 1280.0f, 720.0f);
            gCameraList[entityId] = cameraComponent;
            compMask |= (1u << CameraComponentMask);
        }
        gComponentMaskList[entityId] = compMask;

        entity_count = entity_count + 1u;
    }

    gEntityCount = entity_count;
}