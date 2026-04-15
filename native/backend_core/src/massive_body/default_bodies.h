#pragma once

#include "massive_body/massive_body.h"

#include <vector>

namespace solar {

std::vector<MassiveBody> make_default_bodies();
std::vector<Spacecraft> make_default_spacecraft();

} // namespace solar
