#pragma once

namespace solar {

class Simulation {
public:
    Simulation();
    ~Simulation();

    bool is_running() const;
    void start();
    void stop();

private:
    bool running_ = false;
};

} // namespace solar
