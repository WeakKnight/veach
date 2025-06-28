 // data structure to store output of vertex function
struct VertexOut 
{
    @builtin(position) pos: vec4f,
    @location(0) texCoord: vec2f
};

struct VertexData {
    uv0: vec2f,
    uv1: vec2f,
    position: vec3f,
    normal: vec3f,
    tangent: vec4f
};

@group(0) @binding(0)
var<storage> vertexBuffer: array<f32>;

@group(0) @binding(1)
var<storage> indexBuffer: array<u32>;

fn getVertexData(vertexIndex: u32) -> VertexData {
    let offset = vertexIndex * 56;
    let uv0 = vec2f(vertexBuffer[offset], vertexBuffer[offset + 1]);
    let uv1 = vec2f(vertexBuffer[offset + 2], vertexBuffer[offset + 3]);
    let position = vec3f(vertexBuffer[offset + 4], vertexBuffer[offset + 5], vertexBuffer[offset + 6]);
    let normal = vec3f(vertexBuffer[offset + 7], vertexBuffer[offset + 8], vertexBuffer[offset + 9]);
    let tangent = vec4f(vertexBuffer[offset + 10], vertexBuffer[offset + 11], vertexBuffer[offset + 12], vertexBuffer[offset + 13]);
    return VertexData(uv0, uv1, position, normal, tangent);
}

// process the points of the triangle
@vertex 
fn vs_main(@builtin(vertex_index) vertexIndex : u32) -> VertexOut 
{
    let vertexData = getVertexData(indexBuffer[vertexIndex]);

    var out: VertexOut;
    out.pos = vec4f(vertexData.position, 1.0);
    out.texCoord = vertexData.uv0;

    return out;
}