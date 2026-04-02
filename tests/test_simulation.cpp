#include <gtest/gtest.h>

#include "backend_core/simulation.h"

TEST(SimulationTest, CanInstantiate) {
    solar::Simulation sim;
    EXPECT_FALSE(sim.is_running());
}

TEST(SimulationTest, StartStop) {
    solar::Simulation sim;
    sim.start();
    EXPECT_TRUE(sim.is_running());
    sim.stop();
    EXPECT_FALSE(sim.is_running());
}
