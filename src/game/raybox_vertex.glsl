#version 300 es
layout (location = 0) in vec2 meshPos;
layout (location = 1) in vec4 voxelPosAndSize;
layout (location = 2) in vec3 aColor;

uniform mat4 projMat;
uniform mat4 viewMat;

out vec3 ray;
out vec3 vColor;
flat out mediump vec4 voxelWorldPosAndSize;

void quadricProj(
    in vec3 osPosition,
    in float voxelSize,
    in mat4 modelViewProj,
    in vec2 halfScreenSize,
    inout vec4 position,
    inout float pointSize)
{
    const vec4 quadricMat = vec4(1.0, 1.0, 1.0, -1.0);
    float sphereRadius = voxelSize * 1.732051;
    vec4 sphereCenter = vec4(osPosition.xyz, 1.0);

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
    quadricProj(voxelPosAndSize.xyz, voxelPosAndSize.w, viewMat * projMat, vec2(1.0, 1.0), pos, size);

    vec3 cam_sideways = viewMat[0].xyz;
    vec3 cam_up = viewMat[1].xyz;
    vec3 cam_forward = viewMat[2].xyz;

    if (size > (60.0 / 480.0)) {
        vec3 p = voxelPosAndSize.xyz;
        float e = voxelPosAndSize.w / 2.0;

        vec4 v0 = (vec4(p + vec3( e, e, e), 1.0) * viewMat * projMat);
        vec4 v1 = (vec4(p + vec3( e, e,-e), 1.0) * viewMat * projMat);
        vec4 v2 = (vec4(p + vec3( e,-e, e), 1.0) * viewMat * projMat);
        vec4 v3 = (vec4(p + vec3( e,-e,-e), 1.0) * viewMat * projMat);
        vec4 v4 = (vec4(p + vec3(-e, e, e), 1.0) * viewMat * projMat);
        vec4 v5 = (vec4(p + vec3(-e, e,-e), 1.0) * viewMat * projMat);
        vec4 v6 = (vec4(p + vec3(-e,-e, e), 1.0) * viewMat * projMat);
        vec4 v7 = (vec4(p + vec3(-e,-e,-e), 1.0) * viewMat * projMat);

        if(min(min(min(v0.z, v1.z), min(v2.z, v3.z)), min(min(v4.z, v5.z), min(v6.z, v7.z))) < 0.0) {
            gl_Position = vec4(0.0, 0.0, 2.0, 0.0);
            return;
        }

        vec2 c0 = v0.xy / v0.w;
        vec2 c1 = v1.xy / v1.w;
        vec2 c2 = v2.xy / v2.w;
        vec2 c3 = v3.xy / v3.w;
        vec2 c4 = v4.xy / v4.w;
        vec2 c5 = v5.xy / v5.w;
        vec2 c6 = v6.xy / v6.w;
        vec2 c7 = v7.xy / v7.w;

        vec2 min = vec2(
            min(min(min(c0.x, c1.x), min(c2.x, c3.x)), min(min(c4.x, c5.x), min(c6.x, c7.x))),
            min(min(min(c0.y, c1.y), min(c2.y, c3.y)), min(min(c4.y, c5.y), min(c6.y, c7.y)))
        );

        vec2 max = vec2(
            max(max(max(c0.x, c1.x), max(c2.x, c3.x)), max(max(c4.x, c5.x), max(c6.x, c7.x))),
            max(max(max(c0.y, c1.y), max(c2.y, c3.y)), max(max(c4.y, c5.y), max(c6.y, c7.y)))
        );

        pos.xy = (max + min) / 2.0;
        pos.xy += meshPos.xy * (max - min);
    } else {
        pos.xy += meshPos.xy * size / 2.0;
    }

    gl_Position = vec4(pos.xy, 0.0, 1.0);
    ray = pos.x * cam_sideways + pos.y * cam_up - 1.0 * cam_forward;
    vColor = aColor;
    voxelWorldPosAndSize = voxelPosAndSize;
}
