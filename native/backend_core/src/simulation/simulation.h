#pragma once

#include "massive_body/massive_body.h"

#include <vector>

namespace solar {

class Simulation {
public:
    Simulation();
    ~Simulation();

    bool is_running() const;
    void start();
    void stop();

    void add_body(MassiveBody body);
    void step(double delta_game_seconds);

    const std::vector<MassiveBody>& bodies() const;
    size_t body_count() const;
    double sim_time() const;

    static constexpr double TIME_SCALE = 2160.0; // 1 game second = 36 real minutes

private:
    bool running_ = false;
    double sim_time_s_ = 0.0;
    std::vector<MassiveBody> bodies_;
};

} // namespace solar
