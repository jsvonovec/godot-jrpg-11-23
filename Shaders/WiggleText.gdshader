shader_type canvas_item;


uniform float amplitude;
uniform float speed;
uniform float wiggle;
uniform float tempo;


void vertex(){
	
	VERTEX += vec2(sin(TIME * speed * tempo / 19.1 + VERTEX.x * wiggle) * amplitude, 
	cos(TIME * speed + VERTEX.x * wiggle * tempo / 19.1) * amplitude);
	
}