 // data structure to store output of vertex function
struct VertexOut 
{
    @builtin(position) pos: vec4f,
    @location(0) texCoord: vec2f
};

// process the points of the triangle
@vertex 
fn vs(@builtin(vertex_index) vertexIndex : u32) -> VertexOut 
{
    let pos = array(
        vec2f(-1, 1),  // top left
        vec2f(-1, -1),  // bottom left
        vec2f(1, -1), // bottom right
        vec2f(1, -1),
        vec2f(1, 1),
        vec2f(-1, 1)   
    );

    let texCoord = array(
        vec2f(0.0, .0),
        vec2f( .0, 1.),
        vec2f( 1.0, 1.0),
        vec2f(1.0, 1.0),
        vec2f( 1.0, 0.),
        vec2f( 0.0, .0)
    );

    var out: VertexOut;
    out.pos = vec4f(pos[vertexIndex], 0.0, 1.0);
    out.texCoord = texCoord[vertexIndex];

    return out;
}