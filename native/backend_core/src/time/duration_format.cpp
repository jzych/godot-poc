#include "time/duration_format.h"

#include <cmath>
#include <cstdint>
#include <sstream>
#include <string>
#include <vector>

namespace solar {

std::string format_duration_ydhms(double total_seconds) {
    if (!std::isfinite(total_seconds) || total_seconds <= 0.0) {
        return "0s";
    }

    constexpr std::int64_t seconds_per_minute = 60;
    constexpr std::int64_t seconds_per_hour = 60 * seconds_per_minute;
    constexpr std::int64_t seconds_per_day = 24 * seconds_per_hour;
    constexpr std::int64_t seconds_per_year = 365 * seconds_per_day;

    std::int64_t remaining_seconds =
        static_cast<std::int64_t>(std::llround(total_seconds));

    const std::int64_t years = remaining_seconds / seconds_per_year;
    remaining_seconds %= seconds_per_year;

    const std::int64_t days = remaining_seconds / seconds_per_day;
    remaining_seconds %= seconds_per_day;

    const std::int64_t hours = remaining_seconds / seconds_per_hour;
    remaining_seconds %= seconds_per_hour;

    const std::int64_t minutes = remaining_seconds / seconds_per_minute;
    remaining_seconds %= seconds_per_minute;

    const std::int64_t seconds = remaining_seconds;

    std::vector<std::string> parts;
    if (years > 0) {
        parts.push_back(std::to_string(years) + "y");
    }
    if (days > 0) {
        parts.push_back(std::to_string(days) + "d");
    }
    if (hours > 0) {
        parts.push_back(std::to_string(hours) + "h");
    }
    if (minutes > 0) {
        parts.push_back(std::to_string(minutes) + "min");
    }
    if (seconds > 0 || parts.empty()) {
        parts.push_back(std::to_string(seconds) + "s");
    }

    std::ostringstream stream;
    for (size_t index = 0; index < parts.size(); ++index) {
        if (index > 0) {
            stream << ' ';
        }
        stream << parts[index];
    }

    return stream.str();
}

} // namespace solar
