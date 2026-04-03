#pragma once

#include <string>

namespace solar {

struct Vec3 {
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
};

struct Color3 {
    float r = 1.0f;
    float g = 1.0f;
    float b = 1.0f;
};

enum class MassiveBodyType {
    Sun,
    Earth,
    Moon,
};

struct MassiveBody {
    MassiveBodyType type{};
    std::string name;
    double orbital_radius_km = 0.0;
    double orbital_period_s = 0.0;
    int parent_index = -1;
    Color3 color;
    Vec3 position_km;
};

} // namespace solar
