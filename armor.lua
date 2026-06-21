--======================
-- BESKAR
--======================

armor:register_armor("star_wars:helmet_beskar", {
	description = ("Beskar Helmet"),
	inventory_image = "star_wars_beskar_helmet_inv.png",
	groups = {armor_head=1, armor_heal=14, armor_use=100, armor_fire=1},
	armor_groups = {fleshy=18},
	damage_groups = {cracky=3, snappy=2, level=3},
})

armor:register_armor("star_wars:chestplate_beskar", {
	description = ("Beskar Chestplate"),
	inventory_image = "star_wars_beskar_chestplate_inv.png",
	groups = {armor_torso=1, armor_heal=14, armor_use=100, armor_fire=1},
	armor_groups = {fleshy=18},
	damage_groups = {cracky=3, snappy=2, level=3},
})

armor:register_armor("star_wars:leggings_beskar", {
	description = ("Beskar Leggings"),
	inventory_image = "star_wars_beskar_leggings_inv.png",
	groups = {armor_legs=1, armor_heal=14, armor_use=100, armor_fire=1},
	armor_groups = {fleshy=18},
	damage_groups = {cracky=3, snappy=2, level=3},
})

armor:register_armor("star_wars:boots_beskar", {
	description = ("Beskar Boots"),
	inventory_image = "star_wars_beskar_boots_inv.png",
	groups = {armor_feet=1, armor_heal=14, armor_use=100, armor_fire=1},
	armor_groups = {fleshy=18},
	damage_groups = {cracky=3, snappy=2, level=3},
})
