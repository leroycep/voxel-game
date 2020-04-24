#version 300 es
layout (location = 0) in vec3 meshPos;
layout (location = 1) in vec4 billboardPosAndSize;
layout (location = 2) in vec3 aColor;
uniform mat4 projectionMatrix;

out vec3 vColor;

void main()
{ 
    float size = billboardPosAndSize.w;
    gl_Position = vec4(meshPos.x * size + billboardPosAndSize.x, meshPos.y * size + billboardPosAndSize.y, meshPos.z * size + billboardPosAndSize.z, 1.0) * projectionMatrix;
    vColor = aColor;
}
