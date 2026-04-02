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
cmake -B build
cmake --build build
```

## Test

```bash
ctest --test-dir build
```

- C++ tests: gtest (via FetchContent)
- Godot tests: GUT addon, run headless via cmake `godot_bridge_smoke` test

## Key Conventions
- `backend_core` must NOT include any Godot or godot-cpp headers
- godot-cpp pinned to `4.5` branch (latest available; compatible with Godot 4.6)
- CMake minimum 3.21, C++20 standard required
