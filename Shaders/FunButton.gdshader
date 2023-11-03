shader_type canvas_item;


uniform sampler2D noise;
uniform sampler2D bg;
uniform vec4 color;
uniform float speed;


void fragment(){
	if(COLOR.rgb == vec3(1.0, 0.0, 0.0)){
	
		//COLOR = vec4(0.5, 0.5, 0.5, 0.1);
		//float alpha = 1.0 - UV.x;
		float alpha = 1.0;
		vec4 txt = texture(noise, vec2(mod(UV.x - (TIME * speed), 1.0), mod(UV.y - (TIME * 0.25 * speed), 1.0)));
		txt += texture(noise, vec2(mod(UV.x - (TIME * speed * 0.33), 1.0), mod(UV.y - (TIME * 0.44*speed), 1.0)));
		txt += texture(noise, vec2(mod(UV.x - (TIME * speed * 0.1), 1.0), mod(UV.y - (TIME * 0.15*speed), 1.0))) * 0.7;
		alpha *= txt.r;
		alpha *= float(alpha > 0.25);
		alpha *= min(min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y)) * 5.0, 1.0);
		alpha *= float(alpha > 0.15);
		alpha *= max(abs(UV.x - 0.5), abs(UV.y - 0.5));
		txt *= color;
		txt.a = alpha;
		COLOR = txt;
	}
	else{
		COLOR = texture(TEXTURE, UV);
	}
}