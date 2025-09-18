#include "vertex-factory.slang"

struct VertexStageOutput
{
    float4 positionClipSpace : SV_POSITION;
    [[vk::location(0)]] float2 texCoord0 : TEXCOORD0;
    [[vk::location(1)]] float2 texCoord1 : TEXCOORD1;
};

struct FragmentStageOutput
{
    float4 color : SV_TARGET0;
};


[shader("vertex")]
VertexStageOutput vertexMain(uint vertexIndex: SV_VertexID)
{
    VertexData vertexData = GetVertexData(IndexBuffer[vertexIndex]);
    VertexStageOutput output;
    output.positionClipSpace = float4(vertexData.position, 1);
    output.texCoord0 = vertexData.uv0;
    output.texCoord1 = vertexData.uv0;
    return output;
}

[shader("fragment")]
FragmentStageOutput fragmentMain(VertexStageOutput fragmentInput)
{
    FragmentStageOutput output;
    output.color = float4(fragmentInput.texCoord0, 0, 1);
    return output;
}