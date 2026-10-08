// Flat colour chosen per instance, for meshes the game colours at runtime
// (printed items take the colour of their filament).
// Set with GeometryInstance3D.set_instance_shader_parameter("tint", colour).
shader_type spatial;

instance uniform vec3 tint : source_color = vec3(0.85, 0.85, 0.85);

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
