 // data structure to store output of vertex function
struct VertexOut 
{
    @builtin(position) pos: vec4f,
    @location(0) texCoord: vec2f
};

struct VertexData {
    position: vec3f,
    normal: vec3f,
    uv0: vec2f,
};

@group(0) @binding(0)
var<storage> vertexBuffer: array<f32>;

@group(0) @binding(1)
var<storage> indexBuffer: array<u32>;

fn getVertexData(vertexIndex: u32) -> VertexData {
    let offset = vertexIndex * 8u;
    let position = vec3f(vertexBuffer[offset + 0u], vertexBuffer[offset + 1u], vertexBuffer[offset + 2u]);
    let normal = vec3f(vertexBuffer[offset + 3u], vertexBuffer[offset + 4u], vertexBuffer[offset + 5u]);
    let uv0 = vec2f(vertexBuffer[offset + 6u], vertexBuffer[offset + 7u]);
    return VertexData(position, normal, uv0);
}

// process the points of the triangle
@vertex 
fn vs_main(@builtin(vertex_index) vertexIndex : u32) -> VertexOut 
{
    var out: VertexOut;
    let vertexData = getVertexData(indexBuffer[vertexIndex]);
    out.pos = vec4f(vertexData.position, 1.0f);
    out.texCoord = vertexData.uv0;

    return out;
}