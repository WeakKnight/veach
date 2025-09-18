#include "vertex-factory.slang"

[shader("vertex")]
VertexStageOutput vertexMain(uint vertexIndex: SV_VertexID) : SV_Position
{
    VertexData vertexData = GetVertexData(IndexBuffer[vertexIndex]);
    VertexStageOutput output;
    output.positionClipSpace = float4(vertexData.position, 1);
    output.texCoord = vertexData.uv0;
    return output;
}

[shader("fragment")]
FragmentStageOutput fragmentMain(in VertexStageOutput fragmentInput)
{
    FragmentStageOutput output;
    output.color = float4(fragmentInput.texCoord, 0, 1);
    return output;
}