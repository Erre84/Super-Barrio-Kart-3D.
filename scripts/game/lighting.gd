extends RefCounted
## Iluminación y ambiente de El Prat (compartido por el juego y las capturas).
## Tarde soleada mediterránea: sol cálido y algo bajo (sombras largas que
## modelan los volúmenes), luz de relleno fría desde el lado contrario para que
## las caras en sombra no queden planas, neblina cálida de costa y brillo suave.

static func build(parent: Node, quality_mobile: bool = false) -> Dictionary:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3a83de")
	sky_mat.sky_horizon_color = Color("f1dcc0")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color("f1dcc0")
	sky_mat.ground_bottom_color = Color("9a9a80")
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.1
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b3c3d8")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.02
	env.tonemap_white = 1.3
	# Neblina cálida: separa planos y da profundidad sin coste
	env.fog_enabled = true
	env.fog_light_color = Color("e7dccb")
	env.fog_density = 0.0013
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.25
	# Brillo suave en luces, faros, chispas y llamas
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.92
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Ajuste de color: un punto más de saturación arcade
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -42, 0)
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 1.25
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.3
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.18
	sun.directional_shadow_max_distance = 60.0 if quality_mobile else 95.0
	sun.directional_shadow_fade_start = 0.85
	parent.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-22, 140, 0)
	fill.light_color = Color("9dbcff")
	fill.light_energy = 0.3
	fill.light_specular = 0.2
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY  # que no pinte un segundo "sol" en el cielo
	parent.add_child(fill)
	return {"environment": env, "sun": sun, "fill": fill}
