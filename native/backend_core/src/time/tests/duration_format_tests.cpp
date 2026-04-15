#include <gtest/gtest.h>

#include <limits>

#include "time/duration_format.h"

TEST(DurationFormatTest, ReturnsZeroSecondsForZero) {
    EXPECT_EQ(solar::format_duration_ydhms(0.0), "0s");
}

TEST(DurationFormatTest, OmitsZeroUnits) {
    const double total_seconds = 6.0 * 3600.0 + 15.0 * 60.0 + 12.0;
    EXPECT_EQ(solar::format_duration_ydhms(total_seconds), "6h 15min 12s");
}

TEST(DurationFormatTest, FormatsFullMultiUnitDuration) {
    const double total_seconds =
        387.0 * 24.0 * 3600.0 + 6.0 * 3600.0 + 30.0 * 60.0 + 5.0;
    EXPECT_EQ(solar::format_duration_ydhms(total_seconds),
              "1y 22d 6h 30min 5s");
}

TEST(DurationFormatTest, ReturnsZeroSecondsForNegativeDuration) {
    EXPECT_EQ(solar::format_duration_ydhms(-12.0), "0s");
}

TEST(DurationFormatTest, ReturnsZeroSecondsForNonFiniteDuration) {
    EXPECT_EQ(
        solar::format_duration_ydhms(std::numeric_limits<double>::infinity()),
        "0s");
    EXPECT_EQ(
        solar::format_duration_ydhms(std::numeric_limits<double>::quiet_NaN()),
        "0s");
}

TEST(DurationFormatTest, RoundsFractionalSecondsBeforeFormatting) {
    EXPECT_EQ(solar::format_duration_ydhms(59.6), "1min");
}
