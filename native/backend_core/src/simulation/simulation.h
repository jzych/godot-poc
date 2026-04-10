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
    void add_spacecraft(Spacecraft spacecraft);
    void step(double delta_game_seconds);

    const std::vector<MassiveBody>& bodies() const;
    const std::vector<Spacecraft>& spacecraft() const;
    size_t body_count() const;
    size_t spacecraft_count() const;
    double sim_time() const;

    static constexpr double TIME_SCALE = 1080.0; // 1 game second = 18 real minutes

private:
    bool running_ = false;
    double sim_time_s_ = 0.0;
    std::vector<MassiveBody> bodies_;
    std::vector<Spacecraft> spacecraft_;
};

} // namespace solar
