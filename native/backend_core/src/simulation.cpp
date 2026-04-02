#include "backend_core/simulation.h"

namespace solar {

Simulation::Simulation() = default;
Simulation::~Simulation() = default;

bool Simulation::is_running() const { return running_; }

void Simulation::start() { running_ = true; }

void Simulation::stop() { running_ = false; }

} // namespace solar
