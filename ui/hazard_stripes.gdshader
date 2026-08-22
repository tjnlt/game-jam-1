shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.95, 0.8, 0.05, 1.0);
uniform vec4 color_b : source_color = vec4(0.07, 0.07, 0.07, 1.0);
uniform float stripe_width : hint_range(4.0, 200.0) = 36.0;

void fragment() {
	float coord = (FRAGCOORD.x + FRAGCOORD.y) / stripe_width;
	float stripe = mod(floor(coord), 2.0);
	COLOR = mix(color_a, color_b, stripe);
}
