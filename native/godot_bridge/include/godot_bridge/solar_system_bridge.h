#pragma once

#include <godot_cpp/classes/node.hpp>

namespace solar {

class SolarSystemBridge : public godot::Node {
    GDCLASS(SolarSystemBridge, godot::Node)

public:
    SolarSystemBridge();
    ~SolarSystemBridge() override;

    void _ready() override;
    void _process(double delta) override;

    bool is_simulation_running() const;

protected:
    static void _bind_methods();

private:
    bool simulation_running_ = false;
};

} // namespace solar
