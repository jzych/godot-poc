extends GutTest

func test_bridge_class_exists():
	var bridge = SolarSystemBridge.new()
	assert_not_null(bridge, "SolarSystemBridge should instantiate")
	assert_true(bridge is Node, "SolarSystemBridge should be a Node")
	bridge.free()

func test_bridge_simulation_not_running():
	var bridge = SolarSystemBridge.new()
	assert_false(bridge.is_simulation_running(), "Simulation should not be running initially")
	bridge.free()
