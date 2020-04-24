pub fn mul(a: [16]f32, b: [16]f32) [16]f32 {
    var c: [16]f32 = undefined;
    comptime var i: usize = 0;
    inline while (i < 4) : (i += 1) {
        comptime var j: usize = 0;
        inline while (j < 4) : (j += 1) {
            c[i * 4 + j] = 0;
            comptime var k: usize = 0;
            inline while (k < 4) : (k += 1) {
                c[i * 4 + j] += a[i * 4 + k] * b[k * 4 + j];
            }
        }
    }
    return c;
}
