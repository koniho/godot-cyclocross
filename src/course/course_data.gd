# course_data.gd
# Resource containing all data for a complete course
# Save instances as .tres files in resources/courses/

class_name CourseData
extends Resource

@export var id: String = ""
@export var display_name: String = "Unnamed Course"
@export var description: String = ""
@export var lap_count: int = 3
@export var segments: Array[CourseSegment] = []
@export var preview_color: Color = Color(0.3, 0.5, 0.2)
