#version 300 es

uniform highp vec3 cam_pos;
uniform highp float far;

flat in mediump vec4 voxelWorldPosAndSize;
in mediump vec3 ray;
in mediump vec3 vColor;

out mediump vec4 FragColor;

struct Ray {
    mediump vec3     origin;
    mediump vec3     direction;
};

struct Box {
    mediump vec3      center;
    mediump vec3     radius;
    mediump vec3     invRadius;
    mediump mat3     rotation;
};

mediump float maxComponent(in mediump vec3 v) {
    return max( max ( v.x, v.y ), v.z );
}


/* Our ray-box intersection */

// vec3 box.radius:       independent half-length along the X, Y, and Z axes
// mat3 box.rotation:     box-to-world rotation (orthonormal 3x3 matrix) transformation
// bool rayCanStartInBox: if true, assume the origin is never in a box. GLSL optimizes this at compile time
// bool oriented:         if false, ignore box.rotation
bool ourIntersectBoxCommon(Box box, Ray ray, out mediump float distance, out mediump vec3 normal, const bool rayCanStartInBox, const in bool oriented, in mediump vec3 _invRayDirection) {

    // Move to the box's reference frame. This is unavoidable and un-optimizable.
    ray.origin = box.rotation * (ray.origin - box.center);
    if (oriented) {
        ray.direction = ray.direction * box.rotation;
    }

    // This "rayCanStartInBox" branch is evaluated at compile time because `const` in GLSL
    // means compile-time constant. The multiplication by 1.0 will likewise be compiled out
    // when rayCanStartInBox = false.
    mediump float winding;
    if (rayCanStartInBox) {
        // Winding direction: -1 if the ray starts inside of the box (i.e., and is leaving), +1 if it is starting outside of the box
        winding = (maxComponent(abs(ray.origin) * box.invRadius) < 1.0) ? -1.0 : 1.0;
    } else {
        winding = 1.0;
    }

    // We'll use the negated sign of the ray direction in several places, so precompute it.
    // The sign() instruction is fast...but surprisingly not so fast that storing the result
    // temporarily isn't an advantage.
    mediump vec3 sgn = -sign(ray.direction);

    // Ray-plane intersection. For each pair of planes, choose the one that is front-facing
    // to the ray and compute the distance to it.
    mediump vec3 distanceToPlane = box.radius * winding * sgn - ray.origin;
    if (oriented) {
        distanceToPlane /= ray.direction;
    } else {
        distanceToPlane *= _invRayDirection;
    }

    // Perform all three ray-box tests and cast to 0 or 1 on each axis. 
    // Use a macro to eliminate the redundant code (no efficiency boost from doing so, of course!)
    // Could be written with
#   define TEST(U, VW)\
         /* Is there a hit on this axis in front of the origin? Use multiplication instead of && for a small speedup */\
         (distanceToPlane.U >= 0.0) && \
         /* Is that hit within the face of the box? */\
         all(lessThan(abs(ray.origin.VW + ray.direction.VW * distanceToPlane.U), box.radius.VW))

    bvec3 test = bvec3(TEST(x, yz), TEST(y, zx), TEST(z, xy));

    // CMOV chain that guarantees exactly one element of sgn is preserved and that the value has the right sign
    sgn = test.x ? vec3(sgn.x, 0.0, 0.0) : (test.y ? vec3(0.0, sgn.y, 0.0) : vec3(0.0, 0.0, test.z ? sgn.z : 0.0));
#   undef TEST

    // At most one element of sgn is non-zero now. That element carries the negative sign of the
    // ray direction as well. Notice that we were able to drop storage of the test vector from registers,
    // because it will never be used again.

    // Mask the distance by the non-zero axis
    // Dot product is faster than this CMOV chain, but doesn't work when distanceToPlane contains nans or infs.
    //
    distance = (sgn.x != 0.0) ? distanceToPlane.x : ((sgn.y != 0.0) ? distanceToPlane.y : distanceToPlane.z);

    // Normal must face back along the ray. If you need
    // to know whether we're entering or leaving the box,
    // then just look at the value of winding. If you need
    // texture coordinates, then use box.invDirection * hitPoint.

    if (oriented) {
        normal = box.rotation * sgn;
    } else {
        normal = sgn;
    }

    return (sgn.x != 0.0) || (sgn.y != 0.0) || (sgn.z != 0.0);
}

void main()
{
    mediump vec3 rayOrigin = cam_pos;
    mediump vec3 rayDirection = normalize(ray);
    mediump vec3 invRayDirection = 1.0 / rayDirection;

    mediump vec3 boxCenter = voxelWorldPosAndSize.xyz;
    mediump vec3 boxRadius = vec3(voxelWorldPosAndSize.w / 2.0);
    mediump vec3 invBoxRadius = 1.0 / boxRadius;
    mediump mat3 rotation = mat3(
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, 1.0, 0.0),
        vec3(0.0, 0.0, 1.0)
    );

    Box box = Box(boxCenter, boxRadius, invBoxRadius, rotation);
    Ray ray = Ray(rayOrigin, rayDirection);

    mediump float distance;
    mediump vec3 normal;

    if (!ourIntersectBoxCommon(box, ray, distance, normal, true, false, invRayDirection)) {
        discard;
    } else {
        gl_FragDepth = distance / far;
        FragColor = vec4(vColor.xyz, 1.0);
    }
}
