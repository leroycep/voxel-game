#version 300 es
layout (location = 0) in vec3 meshPos;
layout (location = 1) in vec4 xyzs;
layout (location = 2) in vec3 aColor;

uniform vec3 camera_right;
uniform vec3 camera_up;
uniform mat4 VP;

out vec3 vColor;

void main()
{ 
    float size = xyzs.w;
    vec3 center = xyzs.xyz;
    vec3 pos = center + (camera_right * meshPos.x * size) + (camera_up * meshPos.y * size);

    gl_Position = vec4(pos, 1.0) * VP;
/*
    gl_Position = vec4(meshPos.x * size + xyzs.x,
                       meshPos.y * size + xyzs.y,
                       meshPos.z * size + xyzs.z,
                       1.0) * VP;
*/
    vColor = aColor;
}
