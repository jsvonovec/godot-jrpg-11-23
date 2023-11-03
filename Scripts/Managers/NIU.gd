extends Node

class_name NIU


static func intmin(a,b) -> int:
	return int(min(a,b))
static func intmax(a,b) -> int:
	return int(max(a,b))

# Returns a comma-separated string of names of nodes.
static func cs_names(ns: Array) -> String:
	if len(ns) < 1: return ""
	var results: String = ns[0]._get_name() if ns[0].has_method("_get_name"
	) else ns[0].name
	for i in range(1,len(ns)):
		results += ", " + ns[i]._get_name() if ns[i].has_method("_get_name"
		) else ", " + ns[i].name
	return results

static func sign_string(amt) -> String:
	if amt < 0:
		return "-"
	if amt > 0:
		return "+"
	return ""


static func format_string(string: String, subject: Node):
	var newdesc := string
	var i := 0
	var j := -1
	var origval : String
	for c in string:
		if c == '{'[0]:
			j = string.findn('}', i)
			if j > 0:
				origval = ""
				# grab whatever's between { and }
				origval = string.right(i+1).left(j-i-1)
				# Now determine if it's a parameter or a fxn we need.
				# PARAMETER
				if origval.findn("()") == -1:
					newdesc = newdesc.format(
						[[origval, str(subject.get(origval))]])
				# VOID METHOD
				else:
					j = origval.findn("(")
					newdesc = newdesc.format(
						[[origval, str(subject.call(origval.left(j)))]])
		i += 1
	return newdesc


# Returns the theme that's taking effect on the given node, or null
# if none is found (which means the default theme is active - I
# do not know how to access that theme, though.)
static func find_theme(node: Node) -> Theme:
	while node != null:
		if node.theme != null:
			return node.theme
		node = node.get_parent()
	return null


static func plur_s(amt) -> String:
	if (amt is int and amt != 1) or (amt is float and amt != 1.00):
		return "s"
	return ""


static func find_cell(node: Node):
	var p = node.get_parent()
	while is_instance_valid(p):
		if p.get_class_name() == "Cell":
			return p
		p = p.get_parent()
	return node.get_tree().root if iiv(node.get_tree()) else null

static func abs_loc(spatial: Node3D):
	return spatial.global_transform.origin

static func set_abs_loc(spatial: Node3D, loc: Vector3):
	spatial.global_transform.origin = loc

# is instance valid
static func iiv(thing) -> bool:
	return is_instance_valid(thing)


static func get_class_name(obj) -> String:
	if obj.has_method("get_class_name"):
		return obj.get_class_name()
	else:
		return obj.get_class()


static func ftime() -> float:
	return float(Time.get_ticks_msec()) / 1000.0



static func break_point():
	breakpoint
	return


static func v3_within(vector: Vector3, corner1: Vector3, corner2: Vector3):
	var x = max(corner1.x, corner2.x)
	corner1.x = min(corner1.x, corner2.x)
	corner2.x = x
	var y = max(corner1.y, corner2.y)
	corner1.y = min(corner1.y, corner2.y)
	corner2.y = y
	var z = max(corner1.z, corner2.z)
	corner1.z = min(corner1.z, corner2.z)
	corner2.z = z
	return (
	(corner1.x < vector.x) and (vector.x < corner2.x) and
	(corner1.y < vector.y) and (vector.y < corner2.y) and
	(corner1.z < vector.z) and (vector.z < corner2.z))

