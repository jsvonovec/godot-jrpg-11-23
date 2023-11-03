extends Control

# resource bar prefab
@export var resource_bar_prefab : PackedScene
var resource_bar
@export var status_effect_prefab : PackedScene
var status_effect

# The character this card is for.
@onready var chara := get_node("../../../../..")
# the resource prefab instances on our card
var resource_bars : Array
var status_effect_icons : Array
var default_action_position : Vector2

func _ready():
	resource_bar = load(resource_bar_prefab.resource_path)
	status_effect = load(status_effect_prefab.resource_path)
	default_action_position = $Action.position
	# us -> viewport -> TurnCharacterViewport -> character
	#chara.connect("update_ui_now", self, "update")
	resource_bars = Array()
	update_resource_bars()
	update_status_effects()
	

# update our ui to match the PUPPET's stats.
func update():
	if chara == null or chara.pup.dead:
		visible = false
		return
	
	update_resource_bars()
	update_status_effects()
	
	visible = true
	$Card/SelectedPanel/Name.text = chara.rname
	if chara.on_players_team: 
		$Card/SelectedPanel/Name.text += " (Lv. %d)" % chara.level
	$Card/Bars/BarCont/HealthBar/Bar.max_value = chara.pup.max_hp
	$Card/Bars/BarCont/HealthBar/Bar.value = chara.pup.hp
	$Card/Bars/BarCont/HealthBar.character = chara
	$Card/Bars/BarCont/HealthBar.queue_redraw()
	if chara.on_players_team and chara.selected_action != null:
		$Action/Margin/List/Action.text = chara.selected_action._get_name()
		$Action/Margin/List/Target.text = NIU.cs_names(chara.selected_targets)
		$Action.visible = true
	else:
		$Action.visible = false
	
	# do the same for resource bars
	for rbar in resource_bars:
		rbar.get_node("Bar").max_value = chara.pup.max_res[rbar.resource_number]
		rbar.get_node("Bar").value = chara.pup.res[rbar.resource_number]
		rbar.character = chara
		rbar.queue_redraw()

# update our resource bars. Add more, remove them, etc. Whatever.
func update_resource_bars():
	# ADD BARS
	for resource in chara.revealed_resource:
		# check if this resource has a bar for it
		var resource_has_a_bar = false
		for rbar in resource_bars:
			if rbar.resource_number == resource:
				# this resource is good - it has a bar.
				resource_has_a_bar = true
				break
		# create new bar if there is not a bar for it
		if !resource_has_a_bar:
			var rb = resource_bar.instantiate()
			#print(resource)
			rb.resource_number = resource
			rb.character = chara
			rb.bar_color = CombatUI.RESOURCE_COLORS[resource]
			rb.text_color = CombatUI.RESOURCE_COLORS[resource] * 0.8
			rb.res_name = CombatUI.RESOURCE_NAMES[resource]
			add_resource_bar(rb)
	
	# REMOVE BARS
	for rbar in resource_bars:
		if !chara.revealed_resource.has(rbar.resource_number):
			remove_resource_bar(rbar)
	
	# FOR WHEN WE HAVE THE CORRECT NUMBER OF BARS
	#for res in chara.revealed_resource:
		#pass
	
	$Card.shrink_rect()


# for use in update_resource_bars()
func add_resource_bar(bar : ResourceBar):
	# skip if it's already added
	if bar == null or resource_bars.has(bar):
		return
	# add to array
	resource_bars.append(bar)
	# reparent
	if bar.get_parent() != null:
		bar.get_parent().remove_child(bar)
	$Card/Bars/BarCont.add_child(bar)

func remove_resource_bar(bar : ResourceBar):
	# skip if it's already removed
	if bar == null:
		return
	# remove from array
	if resource_bars.has(bar):
		resource_bars.erase(bar)
	# delete
	if bar.get_parent() != null:
		bar.get_parent().remove_child(bar)
	bar.queue_free()

func update_status_effects():
	if is_instance_valid(chara.pup) and !chara.pup.matching_character:
		return
	# set numbers and textures to what's actually on the character.
	# Should be called at the end of each turn, in case
	# the anims get a number wrong or something.
	for se in chara.status_effects_active:
		show_se_icon(se)
	for icon in status_effect_icons:
		if !icon.status_effect in chara.status_effects_active:
			hide_se_icon(icon.status_effect)
		icon.set_stacks(icon.status_effect.stacks)
		icon.set_dur(icon.status_effect.duration)
		icon.set_extra(icon.status_effect.extra_info)
		icon.texture = icon.status_effect.icon
		
	
	$Card.shrink_rect()

func set_status_effect_icon_info(se, _show = null, stacks = null, dur = null, 
extra = null, texture = null) -> void:
	var icon
	if _show is bool:
		if !_show:
			hide_se_icon(se)
			return
		icon = show_se_icon(se)
	else:
		for i in status_effect_icons:
			if i.status_effect == se:
				icon = i
				break
	
	# no icon found; create one
	if !is_instance_valid(icon):
		show_se_icon(se)
		set_status_effect_icon_info(se, show, stacks, dur, extra, texture)
	
	if stacks is int:
		icon.set_stacks(stacks)
	if dur is int:
		icon.set_dur(dur)
	if extra is String:
		icon.set_extra(extra)
	if texture is Texture2D:
		icon.texture = texture

func show_se_icon(se):
	# find the icon to show
	var icon
	for ic in status_effect_icons:
		if ic.status_effect == se:
			icon = ic
			break
	# create new icon
	if is_instance_valid(icon):
		return icon
	icon = status_effect.instantiate()
	#print(stat_eff)
	icon.status_effect = se
	icon.character = se.affected
	add_status_effect_icon(icon)
	return icon

func hide_se_icon(se):
	# find the icon to hide
	for ic in status_effect_icons:
		if ic.status_effect == se:
			remove_status_effect_icon(ic)
			return


# for use in update_resource_bars()
func add_status_effect_icon(icon):
	# skip if it's already added
	if icon == null or status_effect_icons.has(icon):
		return
	# add to array
	status_effect_icons.append(icon)
	# reparent
	if icon.get_parent() != null:
		icon.get_parent().remove_child(icon)
	if icon.status_effect.is_buff:
		$SEs/Buffs.add_child(icon)
	else:
		$SEs/Debuffs.add_child(icon)

func remove_status_effect_icon(icon):
	# skip if it's already removed
	if icon == null:
		return
	# remove from array
	if status_effect_icons.has(icon):
		status_effect_icons.erase(icon)
	# delete
	if icon.get_parent() != null:
		icon.get_parent().remove_child(icon)
	icon.queue_free()

# boolean comparison function for chara.
func character_is(other):
	return chara == other

# When our character is highlighted
func highlight():
	if chara.on_players_team:
		#$Card.visible = true
		#$Action.rect_position = default_action_position
		pass
	modulate = "ffdd40"

# When our character is no longer highlighted
func un_highlight():
	if chara.on_players_team:
		#$Card.visible = false
		#$Action.rect_position.x = -$Action.rect_size.x/2
		pass
	modulate = Color.WHITE



