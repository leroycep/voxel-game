#version 300 es
in mediump vec3 vColor;

out mediump vec4 FragColor;

void main()
{ 
    FragColor = vec4(vColor.xyz, 1.0);
}
