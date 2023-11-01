shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// NOTE(david): must have environment on camera or in scene for this to work!!
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms color;
uniform vec4 albedo : source_color = vec4(0.75, 0.75, 0.75, 1.0);

group_uniforms outline;
uniform float depth_threshold : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float depth_normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float depth_normal_threshold_scale = 2.0;

group_uniforms edge;
uniform float convex_threshold = 0.1;
uniform float orthogonal_concave_threshold = 1e-5;
uniform float diagonal_concave_threshold = 0.65;

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
	vec2 uv_tl = SCREEN_UV + vec2(-texel_size.x, -texel_size.y);
	vec2 uv_tr = SCREEN_UV + vec2( texel_size.x, -texel_size.y);
	vec2 uv_bl = SCREEN_UV + vec2(-texel_size.x, texel_size.y);
	vec2 uv_br = SCREEN_UV + vec2( texel_size.x, texel_size.y);
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
	vec3 normal_t = texture(normal_roughness_texture, uv_t).xyz * 2.0 - 1.0;
	vec3 normal_b = texture(normal_roughness_texture, uv_b).xyz * 2.0 - 1.0;
	vec3 normal_l = texture(normal_roughness_texture, uv_l).xyz * 2.0 - 1.0;
	vec3 normal_r = texture(normal_roughness_texture, uv_r).xyz * 2.0 - 1.0;
	vec3 normal_tl = texture(normal_roughness_texture, uv_tr).xyz * 2.0 - 1.0;
	vec3 normal_tr = texture(normal_roughness_texture, uv_tl).xyz * 2.0 - 1.0;
	vec3 normal_bl = texture(normal_roughness_texture, uv_bl).xyz * 2.0 - 1.0;
	vec3 normal_br = texture(normal_roughness_texture, uv_br).xyz * 2.0 - 1.0;

	float normal_diff = 1.0 - dot(normal, FORWARD);
	float normal_threshold01 = clamp((normal_diff - depth_normal_threshold) / (1.0 - depth_normal_threshold), 0.0, 1.0);
	float normal_threshold = normal_threshold01 * depth_normal_threshold_scale + 1.0;
	
	float depth_thresh = depth_threshold * normal_threshold;

	// convexity/concavity (this is cool)
	vec3 edge_t = cross(normal, normal_t);
	vec3 edge_b = cross(normal, normal_b);
	vec3 edge_l = cross(normal, normal_l);
	vec3 edge_r = cross(normal, normal_r);
	vec3 edge_tl = cross(normal, normal_tl);
	vec3 edge_tr = cross(normal, normal_tr);
	vec3 edge_bl = cross(normal, normal_bl);
	vec3 edge_br = cross(normal, normal_br);
	
	// how aligned with view
	float normal_f = dot(normal, FORWARD);
	float normal_b_f = dot(normal_b, FORWARD);
	float normal_t_f = dot(normal_t, FORWARD);
	float normal_l_f = dot(normal_l, FORWARD);
	float normal_r_f = dot(normal_r, FORWARD);
	
	// edge
	// top edge
	if (
		// ensure we're below the depth threshold
		abs(vpos.z - vpos_b.z) < depth_thresh &&
		// is the normal more oblique; less aligned with the camera (takes priority when even)
		normal_f <= normal_b_f &&
		// convex edge on the bottom
		edge_b.r > convex_threshold
	) {
		EMISSION = vec3(1, 0, 0);
	}
	// bottom edge
	if (
		abs(vpos.z - vpos_t.z) < depth_thresh &&
		normal_f < normal_t_f &&
		-edge_t.r > convex_threshold
	) {
		EMISSION = vec3(1, 0, 0);
	}
	// right edge
	if (
		abs(vpos.z - vpos_l.z) < depth_thresh &&
		normal_f <= normal_l_f &&
		-edge_l.g > convex_threshold
	) {
		EMISSION = vec3(1, 0, 0);
	}
	// left edge
	if (
		abs(vpos.z - vpos_r.z) < depth_thresh &&
		normal_f < normal_r_f &&
		edge_r.g  > convex_threshold
	) {
		EMISSION = vec3(1, 0, 0);
	}
	
	// outline
	if (
		vpos.z - vpos_b.z > depth_thresh ||
		vpos.z - vpos_t.z > depth_thresh ||
		vpos.z - vpos_r.z > depth_thresh ||
		vpos.z - vpos_l.z > depth_thresh
	) {
		EMISSION = vec3(0, 0, 1);
	} 
	
//	if (EMISSION != vec3(0)) {
//		EMISSION = vec3(1);
//	}

	// === DEBUGS === //
//	EMISSION = vec3(depth_edge);
//	EMISSION = vec3(step(edge_threshold, -edge_b.r));
//	EMISSION = vec3(float(step(1e-2, -edge_b.r) == 0.0));
//	EMISSION = vec3(float(
//		edge_tl.r < 0.65 && edge_tr.r < 0.65 && -edge_br.r < 0.65 && -edge_bl.r < 0.65
//		&& -edge_r.g < 1e-5 && edge_l.g < 1e-5 && -edge_b.r < 1e-5 && edge_t.r < 1e-5
//	));
//	EMISSION = vec3(-edge_bl.r);
//	EMISSION = vec3(-edge_b.r);
//	EMISSION = vec3(float(-edge_r.g < 1e-5));
//	EMISSION = vec3(float(-edge_b.r < 1e-5 && edge_t.r < 1e-5 && edge_l.g < 1e-5 && -edge_r.g < 1e-5));
//	EMISSION = vec3(float(-edge_b.r < 1e-2 && edge_t.r < 1e-2 && edge_l.g < 1e-2 && edge_tl.r < 1e-2));
//	EMISSION = vec3(1.0 - step(0.01, -edge_b.r));
//	EMISSION = vec3(step(edge_threshold, edge_r.g));
//	EMISSION = vec3(step(edge_threshold, pow(edge_r.g, ((1.0 - step(1e-2, -edge_b.r)) * (1.0 - step(1e-2, edge_t.r))))));
//	EMISSION = vec3(step(edge_threshold, edge_r.g * float(-edge_b.r < 1e-5 && edge_t.r < 1e-5 && edge_l.g < 1e-5)));
//	EMISSION = vec3(edge_b.r);
//	EMISSION = vec3(edge_l.g);
//	EMISSION = vec3(step(edge_threshold, edge_b.r * (1.0 - step(1e-5, -edge_r.g)) * (1.0 - step(1e-5, edge_l.g))));
//	EMISSION = vec3(1.0 - depth);
//	EMISSION = vec3(depth);
//	EMISSION = vec3(clamp(vpos.z - vpos_t.z, 0.0, 1.0));
//	EMISSION = normal;
//	EMISSION = step(0.0, cross(normal, normal_r)) - step(0.0, -cross(normal, normal_r));
//	EMISSION = step(edge_threshold, cross(normal, normal_r));
//	EMISSION = step(edge_threshold, edge_tr);
//	EMISSION = vec3(step(edge_threshold, edge_r.g) - step(edge_threshold, edge_tr.r));
//	EMISSION = vec3(-edge_l);
//	EMISSION = vec3(edge_r);
//	EMISSION = vec3(step(edge_threshold, cross(normal_t, normal_r).g));
//	EMISSION = vec3(step(edge_threshold, edge_r.g) * step(edge_threshold, cross(normal_t, normal_r).g));
//	EMISSION = vec3(dot(normal, -RIGHT));
//	EMISSION = screen_color;
//	EMISSION = vec3(step(0.001, vpos.z - vpos_r.z));
//	EMISSION = vec3(screen_roughness);
//	EMISSION = pixel_position;
//	EMISSION = pixel_position_world;
//	EMISSION = vec3(normal);
//	EMISSION = vec3(0.0, 0.0, 1.0);
//	EMISSION = vec3(normal_threshold01);
//	EMISSION = vec3(normal_threshold);
}
