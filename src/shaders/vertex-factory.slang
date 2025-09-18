struct VertexData 
{
    float3 position;
    float3 normal;
    float2 uv0;
};

StructuredBuffer<float> VertexBuffer;
StructuredBuffer<uint> IndexBuffer;

VertexData GetVertexData(uint vertexIndex) 
{
    let offset = vertexIndex * 8u;
    let position = float3(VertexBuffer[offset + 0u], VertexBuffer[offset + 1u], VertexBuffer[offset + 2u]);
    let normal = float3(VertexBuffer[offset + 3u], VertexBuffer[offset + 4u], VertexBuffer[offset + 5u]);
    let uv0 = float2(VertexBuffer[offset + 6u], VertexBuffer[offset + 7u]);
    return VertexData(position, normal, uv0);
}

