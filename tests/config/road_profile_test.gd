extends GdUnitTestSuite
## Road profiles come from data, not code (requirements §4.1, issue #4).

const CODE_DIRS: Array[String] = ["res://core", "res://config"]
const ROAD_LITERALS: Array[String] = ["140", "120", "3.75"]


func test_profile_loads_from_tres(
		path: String,
		id: StringName,
		limit_kmh: float,
		test_parameters: Array = [
			["res://config/road_profiles/motorway.tres", &"motorway", 140.0],
			["res://config/road_profiles/expressway.tres", &"expressway", 120.0],
		]) -> void:
	var profile: RoadProfile = load(path) as RoadProfile
	assert_object(profile).is_not_null()
	assert_str(profile.id).is_equal(id)
	assert_float(profile.speed_limit_kmh).is_equal(limit_kmh)
	assert_int(profile.lane_count).is_equal(2)
	assert_float(profile.lane_width_m).is_equal(3.75)
	assert_float(profile.shoulder_width_m).is_greater(0.0)
	assert_str(profile.display_name_key).is_not_empty()


func test_lane_centers_follow_lane_width() -> void:
	var profile: RoadProfile = load("res://config/road_profiles/motorway.tres") as RoadProfile
	assert_float(profile.lane_center(0)).is_equal_approx(1.875, 1e-9)
	assert_float(profile.lane_center(1)).is_equal_approx(5.625, 1e-9)
	assert_bool(profile.is_lane_on_road(-1)).is_false()
	assert_bool(profile.is_lane_on_road(0)).is_true()
	assert_bool(profile.is_lane_on_road(1)).is_true()
	assert_bool(profile.is_lane_on_road(2)).is_false()


func test_road_values_are_not_hard_coded() -> void:
	var offenders: Array[String] = []
	for dir_path: String in CODE_DIRS:
		for script_path: String in _scripts_under(dir_path):
			var source: String = FileAccess.get_file_as_string(script_path)
			for literal: String in ROAD_LITERALS:
				if source.contains(literal):
					offenders.append("%s contains %s" % [script_path, literal])
	assert_array(offenders).is_empty()


func _scripts_under(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			found.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts_under(dir_path.path_join(sub_dir)))
	return found
