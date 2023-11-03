shader_type spatial;
render_mode unshaded, blend_mix;

uniform float def_id = 0.9;
uniform float def_od = 3.0;
uniform float id = 0.9;
uniform float od = 3.0;
uniform sampler2D tex;
uniform sampler2D noise;
uniform float tfactor1 = 0.0;
uniform float tfactor2 = 0.0;
uniform float repetitions1 = 1.0;
uniform float repetitions2 = 1.0;
uniform float alpha_cutoff = 0.5;
uniform float noise_floor = 0.35;
uniform float tempo = 110.0;
uniform float tempo_offset = 0.0;
uniform float beat_pow = 0.1;
uniform float beat_alpha_cutoff_offset = 0.25;
uniform float beat_color_boost = 0.5;

varying vec3 pos;

void vertex(){
	pos = VERTEX;
}

void fragment() {
//	if(pos.x > 0.0)
//		{discard;}
	float r = length(pos.xz);
	// discard outside of radii
	if (r > od / 2.0 || r < id / 2.0){
		discard;
	}
	float t = TIME;
	float beat_mult = pow(mod(t - tempo_offset, 60.0 / tempo) / (60.0 / tempo), 1);
	float theta = atan(pos.x / pos.z) + (PI * float(pos.z < 0.0));
	vec2 uv1 = vec2((theta + t * tfactor1) / (2.0 * PI) * repetitions1, -(r * 2.0 - id) / (od - id));
	vec2 uv2 = vec2((theta + t * tfactor2) / (2.0 * PI) * repetitions2, -(r * 2.0 - id) / (od - id));
	float alpha = texture(tex, uv1).a * (texture(noise, uv2).r * texture(noise, uv2).a * (1.0 - noise_floor) + noise_floor);
	if(alpha < alpha_cutoff * pow(beat_mult + beat_alpha_cutoff_offset, beat_pow)){
		discard;
	}
	ALBEDO = texture(tex, uv1).rgb * (1.0 + (beat_color_boost * (1.0 - beat_mult)));
	//EMISSION = ALBEDO;
	
}
