shader_type canvas_item;

uniform int spacing;
uniform float res_per_icon;
uniform sampler2D icon;
uniform vec3 fill_color;
uniform vec3 unfill_color;
uniform float value;
uniform float max_value;

uniform float shake_amp;
uniform float rand;
uniform float horiz_t;
uniform float vert_t;

uniform vec2 size;
uniform float scale;
varying vec2 offset;

varying vec2 pixel;
varying vec2 new_UV;
varying float icon_num;
varying float val;

void vertex(){
	offset = (shake_amp + float(spacing)) * vec2(2.0 * float(VERTEX.x < 1.0) - 1.0, 
	2.0 * float(VERTEX.y < 1.0) - 1.0) * (size / min(size.x, size.y));
	VERTEX -= offset;
}


void fragment(){
	pixel = (UV / TEXTURE_PIXEL_SIZE - offset) / scale;
	icon_num = floor(pixel.x / (float(spacing) + 1.0 / TEXTURE_PIXEL_SIZE.x));
	pixel = vec2((pixel.x - floor(icon_num * (1.0 / TEXTURE_PIXEL_SIZE.x + float(spacing)))), pixel.y) - vec2(float(spacing) / 2.0, 0.0);
	//shake
	vec2 shake = vec2(sin(horiz_t * 5.0 + icon_num) * 0.5, cos(vert_t + (icon_num)) * (1.0 - rand));
	pixel += shake * shake_amp;
	new_UV = pixel * TEXTURE_PIXEL_SIZE;
	val = (icon_num * res_per_icon) + (new_UV.x * res_per_icon);
	icon_num = floor(pixel.x / (float(spacing) + 1.0 / TEXTURE_PIXEL_SIZE.x));
	
	
	
	// only 1 row
	if(new_UV.y > 1.0 || new_UV.y < 0.0 || val < 0.0 || val > max_value || val < 0.0 || new_UV.x < 0.0
	// voids between hearts
		|| pixel.x > 1.0 / TEXTURE_PIXEL_SIZE.x){
		//COLOR = vec4(new_UV.y, 1.0 - new_UV.y, 0.0, 1.0);
		discard;
	}
	
	else{
		// draw hearts
		vec3 color;
		if (val <= value) color = fill_color;
		else color = unfill_color;
		COLOR = texture(icon, new_UV) * vec4(color, 1.0);
	}
}