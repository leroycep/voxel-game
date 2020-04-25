#version 300 es
layout (location = 0) in vec2 meshPos;
layout (location = 1) in vec4 voxelPosAndSize;
layout (location = 2) in vec3 aColor;
uniform mat4 projectionMatrix;

out vec3 vColor;
flat out mediump vec4 voxelWorldPosAndSize;

void quadricProj(
    in vec3 osPosition,
    in float voxelSize,
    in mat4 objectToScreenMatrix,
    in vec2 halfScreenSize,
    inout vec4 position,
    inout float pointSize)
{
    const vec4 quadricMat = vec4(1.0, 1.0, 1.0, -1.0);
    float sphereRadius = voxelSize * 1.732051;
    vec4 sphereCenter = vec4(osPosition.xyz, 1.0);
    mat4 modelViewProj = transpose(objectToScreenMatrix);

    mat3x4 matT = mat3x4( mat3(modelViewProj[0].xyz, modelViewProj[1].xyz, modelViewProj[3].xyz) * sphereRadius);
    matT[0].w = dot(sphereCenter, modelViewProj[0]);
    matT[1].w = dot(sphereCenter, modelViewProj[1]);
    matT[2].w = dot(sphereCenter, modelViewProj[3]);

    mat3x4 matD = mat3x4( matT[0] * quadricMat, matT[1] * quadricMat, matT[2] * quadricMat);
    vec4 eqCoefs =
        vec4(
            dot(matD[0], matT[2]), 
            dot(matD[1], matT[2]), 
            dot(matD[0], matT[0]), 
            dot(matD[1], matT[1])
        ) / dot(matD[2], matT[2]);

    vec4 outPosition = vec4(eqCoefs.x, eqCoefs.y, 0.0, 1.0);
    vec2 AABB = sqrt(eqCoefs.xy*eqCoefs.xy - eqCoefs.zw);
    AABB *= halfScreenSize * 2.0;

    position.xy = outPosition.xy * position.w;
    pointSize = max(AABB.x, AABB.y);
}

void main()
{ 
    vec4 pos = vec4(0.0, 0.0, 0.0, 1.0);
    float size = 0.0;
    quadricProj(voxelPosAndSize.xyz, voxelPosAndSize.w, transpose(projectionMatrix), vec2(1.0, 1.0), pos, size);

    gl_Position = vec4(meshPos.x * size / 2.0 + pos.x, meshPos.y * size / 2.0 + pos.y, 0.0, 1.0);
    vColor = aColor;
    voxelWorldPosAndSize = voxelPosAndSize;
}
