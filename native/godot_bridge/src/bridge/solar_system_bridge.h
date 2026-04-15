#pragma once

#include <godot_cpp/classes/node.hpp>

#include "massive_body/default_bodies.h"
#include "simulation/simulation.h"

namespace solar {

class SolarSystemBridge : public godot::Node {
    GDCLASS(SolarSystemBridge, godot::Node)

public:
    SolarSystemBridge();
    ~SolarSystemBridge() override;

    void _ready() override;
    void _process(double delta) override;

    bool is_simulation_running() const;
    int get_body_count() const;
    godot::Dictionary get_body_state(int index) const;
    int get_spacecraft_count() const;
    godot::Dictionary get_spacecraft_state(int index) const;
    int get_focus_target_count() const;
    godot::Dictionary get_focus_target_state(int index) const;
    godot::String format_duration_ydhms(double total_seconds) const;
    double get_sim_time() const;

protected:
    static void _bind_methods();

private:
    Simulation sim_;
};

} // namespace solar
