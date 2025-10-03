// Uniform buffer 结构
struct Uniforms {
    mvpMatrix: mat4x4<f32>,
};

// 绑定 uniform buffer
@group(0) @binding(0) var<uniform> uniforms: Uniforms;

// 顶点数据 storage buffer（显式读取方式）
@group(0) @binding(1) var<storage, read> vertexData: array<f32>;

// 顶点数据结构（匹配 Mesh 类中的 VertexData）
struct VertexData {
    position: vec3f,    // 位置 (3 floats)
    normal: vec3f,      // 法线 (3 floats)
    uv0: vec2f,         // 纹理坐标 (2 floats)
};

// data structure to store output of vertex function
struct VertexOut 
{
    @builtin(position) positionCS: vec4f,
    @location(0) texCoord: vec2f,
    @location(1) normalOS: vec3f
};

// 顶点布局常量（匹配 Mesh 类中的 VERTEX_LAYOUT）
const VERTEX_STRIDE: u32 = 8u;  // 8 floats per vertex (position:3 + normal:3 + uv:2)

// 从 storage buffer 读取顶点数据并封装为 VertexData 结构体
fn getVertexData(vertexIndex: u32) -> VertexData {
    let offset = vertexIndex * VERTEX_STRIDE;
    
    var vertex: VertexData;
    vertex.position = vec3f(
        vertexData[offset + 0u],
        vertexData[offset + 1u], 
        vertexData[offset + 2u]
    );
    vertex.normal = vec3f(
        vertexData[offset + 3u],
        vertexData[offset + 4u],
        vertexData[offset + 5u]
    );
    vertex.uv0 = vec2f(
        vertexData[offset + 6u],
        vertexData[offset + 7u]
    );
    
    return vertex;
}

// process the points of the triangle
@vertex 
fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOut 
{
    var out: VertexOut;
    
    // 从 storage buffer 读取顶点数据
    let vertex = getVertexData(vertexIndex);
    
    // 应用 MVP 变换到位置
    out.positionCS = uniforms.mvpMatrix * vec4f(vertex.position, 1.0f);
    out.texCoord = vertex.uv0;
    
    // 传递对象空间法线
    out.normalOS = vertex.normal;

    return out;
}
