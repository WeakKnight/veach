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
    let offset = vertexIndex * 8;
    let position = vec3f(vertexBuffer[offset + 0], vertexBuffer[offset + 1], vertexBuffer[offset + 2]);
    let normal = vec3f(vertexBuffer[offset + 3], vertexBuffer[offset + 4], vertexBuffer[offset + 5]);
    let uv0 = vec2f(vertexBuffer[offset + 6], vertexBuffer[offset + 7]);
    return VertexData(position, normal, uv0);
}

// process the points of the triangle
@vertex 
fn vs_main(@builtin(vertex_index) vertexIndex : u32) -> VertexOut 
{
     let pos = array(
        vec2f(-1, 1),  // top left
        vec2f(-1, -1),  // bottom left
        vec2f(1, -1), // bottom right
        vec2f(1, -1),
        vec2f(1, 1),
        vec2f(-1, 1)   
    );

    var out: VertexOut;
    let vertexData = getVertexData(indexBuffer[vertexIndex]);
    // out.pos = vec4f(vertexData.position.xy, 0, 1.0);
    out.pos = vec4f(vertexData.position, 1);
    // out.pos = vec4f(pos[vertexIndex], 0, 1);
    out.texCoord = vertexData.uv0;

    return out;
}