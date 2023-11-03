extends Action



func _use(targets):
	#print("%s is Basic Attacking %s for %d damage!" 
	#% [character.name, target.name, self.character.attack])
	for target in targets:
		deal_basic_damage(target)
