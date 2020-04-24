pub fn Vec3(comptime T: type) type {
    return struct {
        items: [3]T,

        pub fn new(items: [3]T) @This() {
            return @This(){ .items = items };
        }

        pub fn sub(self: @This(), other: @This()) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < self.items.len) : (i += 1) {
                res.items[i] = self.items[i] - other.items[i];
            }

            return res;
        }

        pub fn add(self: @This(), other: @This()) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < self.items.len) : (i += 1) {
                res.items[i] = self.items[i] + other.items[i];
            }

            return res;
        }

        pub fn normalize(self: @This()) @This() {
            const mag = self.magnitude();
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < self.items.len) : (i += 1) {
                res.items[i] = self.items[i] / mag;
            }

            return res;
        }

        pub fn magnitude(self: @This()) T {
            var sum: T = 0;
            comptime var i = 0;
            inline while (i < self.items.len) : (i += 1) {
                sum += self.items[i] * self.items[i];
            }
            return @sqrt(sum);
        }

        pub fn cross(self: @This(), other: @This()) @This() {
            return @This(){
                .items = .{
                    self.items[1] * other.items[2] - self.items[2] * other.items[1],
                    self.items[2] * other.items[0] - self.items[0] * other.items[2],
                    self.items[0] * other.items[1] - self.items[1] * other.items[0],
                },
            };
        }

        pub fn dot(self: @This(), other: @This()) T {
            var sum: T = 0;
            comptime var i = 0;
            inline while (i < self.items.len) : (i += 1) {
                sum += self.items[i] * other.items[i];
            }
            return sum;
        }
    };
}
