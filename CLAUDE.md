# Solar System Simulation

Simplified solar system simulation in real scale with UI.

## Tech Stack
- **Backend**: C++20 pure domain library (`backend_core`) — no Godot headers
- **Protocol**: C++ message schema/serializers (`protocol`)
- **Client**: Godot 4.6 for rendering, input, UI, scene orchestration
- **Bridge**: GDExtension adapter (`godot_bridge`) linking Godot ↔ backend
- **Networking**: WebSocket (planned)

## Build

```bash
cmake -B build -DGODOTCPP_DEBUG_CRT=ON
cmake --build build --config Debug
```

## Test

```bash
ctest -C Debug --test-dir build
```

- C++ tests: gtest (via FetchContent), colocated in `src/<group>/tests/`
- Godot tests: GUT addon, run headless via cmake `godot_bridge_smoke` test

## File Layout

Each module uses grouped layout — `.h` next to `.cpp`, unit tests colocated:

```
native/<module>/src/<group>/<class>.h
native/<module>/src/<group>/<class>.cpp
native/<module>/src/<group>/tests/<class>_tests.cpp
```

## Key Conventions
- `backend_core` must NOT include any Godot or godot-cpp headers
- godot-cpp pinned to `4.5` branch (latest available; compatible with Godot 4.6)
- CMake minimum 3.21, C++20 standard required
- Use `std::numbers::pi` (C++20) instead of `M_PI`
- Must pass `-DGODOTCPP_DEBUG_CRT=ON` for Debug builds (MSVC CRT consistency)
