shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// NOTE(david): must have environment on camera or in scene for this to work!!
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms color;
uniform vec4 albedo : source_color = vec4(0.75, 0.75, 0.75, 1.0);

group_uniforms outline;
uniform float depth_threshold : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float depth_normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float depth_normal_threshold_scale = 7.0;

#define RIGHT vec3(1.0, 0.0, 0.0)
#define UP vec3(0.0, 1.0, 0.0)
#define FORWARD vec3(0.0, 0.0, 1.0)

void fragment() {
	ALBEDO = albedo.rgb;
	
	vec2 texel_size = 1.0 / VIEWPORT_SIZE;
	
	// raw depth
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	// unprojected (ndc) position
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	// the perspective divide to get the 3d view space position
	vec3 vpos = upos.xyz / upos.w;
	// the 3d world space position
	vec3 wpos = (INV_VIEW_MATRIX * vec4(vpos, 1.0)).xyz;
	
	vec3 normal = texture(normal_roughness_texture, SCREEN_UV).xyz * 2.0 - 1.0;
	
	// TODO(david): maybe make some macros bro
	vec2 uv_t = SCREEN_UV + vec2(0.0, -texel_size.y);
	vec2 uv_b = SCREEN_UV + vec2(0.0,  texel_size.y);
	vec2 uv_l = SCREEN_UV + vec2(-texel_size.x, 0.0);
	vec2 uv_r = SCREEN_UV + vec2( texel_size.x, 0.0);
	float depth_t = textureLod(depth_texture, uv_t, 0.0).r;
	float depth_b = textureLod(depth_texture, uv_b, 0.0).r;
	float depth_l = textureLod(depth_texture, uv_l, 0.0).r;
	float depth_r = textureLod(depth_texture, uv_r, 0.0).r;
	vec4 upos_t = INV_PROJECTION_MATRIX * vec4(uv_t * 2.0 - 1.0, depth_t, 1.0);
	vec4 upos_b = INV_PROJECTION_MATRIX * vec4(uv_b * 2.0 - 1.0, depth_b, 1.0);
	vec4 upos_l = INV_PROJECTION_MATRIX * vec4(uv_l * 2.0 - 1.0, depth_l, 1.0);
	vec4 upos_r = INV_PROJECTION_MATRIX * vec4(uv_r * 2.0 - 1.0, depth_r, 1.0);
	vec3 vpos_t = upos_t.xyz / upos_t.w;
	vec3 vpos_b = upos_b.xyz / upos_b.w;
	vec3 vpos_l = upos_l.xyz / upos_l.w;
	vec3 vpos_r = upos_r.xyz / upos_r.w;
	
	float normal_diff = 1.0 - dot(normal, FORWARD);
	float normal_threshold01 = clamp((normal_diff - depth_normal_threshold) / (1.0 - depth_normal_threshold), 0.0, 1.0);
	float normal_threshold = normal_threshold01 * depth_normal_threshold_scale + 1.0;
	
	float depth_thresh = depth_threshold * normal_threshold;
	// outline
	if (vpos.z - vpos_b.z > depth_thresh ||
		vpos.z - vpos_t.z > depth_thresh ||
		vpos.z - vpos_r.z > depth_thresh ||
		vpos.z - vpos_l.z > depth_thresh) {
		EMISSION = vec3(0, 0, 1);
	}
	

	// === DEBUGS === //
//	ALBEDO = vec3(depth_edge);
//	ALBEDO = vec3(is_edge_t);
//	ALBEDO = vec3(1.0 - depth);
//	ALBEDO = vec3(depth);
//	ALBEDO = vec3(clamp(vpos.z - vpos_t.z, 0.0, 1.0));
//	ALBEDO = normal;
//	ALBEDO = normal_b;
//	ALBEDO = screen_color;
//	ALBEDO = vec3(screen_roughness);
//	ALBEDO = pixel_position;
//	ALBEDO = pixel_position_world;
//	ALBEDO = vec3(normal_diff);
//	ALBEDO = vec3(0.0, 0.0, 1.0);
//	ALBEDO = vec3(normal_threshold01);
//	ALBEDO = vec3(normal_threshold);
}
