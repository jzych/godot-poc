# Solar System Simulation

[![CI](https://github.com/jzych/godot-poc/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/jzych/godot-poc/actions/workflows/ci.yml)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=jzych_godot-poc&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=jzych_godot-poc)

Real-scale solar system simulation with a Godot 4 frontend and a C++20 simulation backend.
The repository combines a pure native core, a small protocol layer, and a GDExtension bridge used by the Godot client.

## Repository layout

```text
godot/                          Godot 4.6 project, scenes, scripts, and GUT tests
native/backend_core/            Pure C++ simulation code
native/protocol/                Shared message/schema layer for native code
native/godot_bridge/            GDExtension bridge loaded by Godot
native/third_party/godot-cpp/   Vendored godot-cpp bindings
tests/                          GoogleTest suites and headless Godot test wiring
CMakeLists.txt                  Standalone native build entry point
```

## Running tests

```sh
cmake -S . -B build -DBUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

The CMake test suite runs both:
- GoogleTest coverage for the native backend
- Headless Godot smoke and GUT tests when `godot4` or `godot` is available on `PATH`

## Godot development

Open `godot/project.godot` in Godot 4.6.
On Windows, you can install Godot with Scoop:

```powershell
scoop bucket add extras
scoop install extras/godot
```

The native build writes the GDExtension library into `godot/extensions/`, so rebuild with CMake after changing C++ bridge or backend code.
