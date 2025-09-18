#include "vertex-factory.slang"

[shader("vertex")]
VertexStageOutput vertexMain(uint vertexIndex: SV_VertexID)
{
    VertexData vertexData = GetVertexData(IndexBuffer[vertexIndex]);
    VertexStageOutput output;
    output.positionClipSpace = float4(vertexData.position, 1);
    output.texCoord = vertexData.uv0;
    return output;
}

[shader("fragment")]
FragmentStageOutput fragmentMain(VertexStageOutput fragmentInput)
{
    FragmentStageOutput output;
    output.color = float4(fragmentInput.texCoord, 0, 1);
    return output;
}