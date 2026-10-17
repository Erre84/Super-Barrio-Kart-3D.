extends Node3D
## Efectos visuales del kart (v0.2):
##  - Humo de neumáticos: bocanadas low-poly sombreadas que crecen y se desvanecen.
##  - Chispas de derrape: estelas alargadas orientadas a su velocidad + destello
##    en la rueda, del color del nivel de mini-turbo (azul / naranja / morado).
##  - Turbo: llamas cónicas parpadeantes en los escapes + partículas de fuego.
##  - Polvo al pisar tierra.
##  - Sombra de contacto bajo el kart (asienta el kart en el suelo).

const SMOKE_MATERIAL := preload("res://materials/smoke.tres")
const LEVEL_COLORS := [Color(1, 1, 1), Color("3fa9ff"), Color("ff8c1a"), Color("c75cff")]

var kart: CharacterBody3D
var model: Node3D

var _smoke: Array[CPUParticles3D] = []
var _sparks: Array[CPUParticles3D] = []
var _flares: Array[MeshInstance3D] = []
var _flame_meshes: Array[Node3D] = []
var _flame_particles: Array[CPUParticles3D] = []
var _dust: CPUParticles3D
var _shadow: MeshInstance3D
var _t := 0.0

static var _radial_tex: ImageTexture


func setup(k: CharacterBody3D) -> void:
	kart = k
	model = k.model
	_build()


## Textura radial suave generada por código (destellos y sombra de contacto).
static func radial_texture() -> ImageTexture:
	if _radial_tex == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_radial_tex = ImageTexture.create_from_image(img)
	return _radial_tex


func _unshaded(col: Color, additive := false, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if tex != null:
		m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build() -> void:
	# --- Humo: esferas low-poly sombreadas, crecen y se desvanecen ---
	var puff := SphereMesh.new()
	puff.radius = 0.35
	puff.height = 0.6
	puff.radial_segments = 7
	puff.rings = 4
	puff.material = SMOKE_MATERIAL
	var smoke_scale := Curve.new()
	smoke_scale.add_point(Vector2(0.0, 0.35))
	smoke_scale.add_point(Vector2(0.3, 1.0))
	smoke_scale.add_point(Vector2(1.0, 1.9))
	var smoke_color := Gradient.new()
	smoke_color.set_color(0, Color(0.96, 0.96, 0.97, 0.85))
	smoke_color.set_color(1, Color(0.85, 0.86, 0.9, 0.0))
	for p in model.rear_wheel_points:
		var sm := CPUParticles3D.new()
		sm.mesh = puff
		sm.amount = 36
		sm.lifetime = 1.1
		sm.emitting = false
		sm.local_coords = false
		sm.position = p + Vector3(0, 0.15, 0.15)
		sm.direction = Vector3(0, 0.6, 1)
		sm.spread = 28.0
		sm.initial_velocity_min = 0.8
		sm.initial_velocity_max = 2.2
		sm.gravity = Vector3(0, 0.9, 0)
		sm.damping_min = 1.0
		sm.damping_max = 2.0
		sm.angle_min = -180
		sm.angle_max = 180
		sm.scale_amount_min = 0.6
		sm.scale_amount_max = 1.2
		sm.scale_amount_curve = smoke_scale
		sm.color_ramp = smoke_color
		model.add_child(sm)
		_smoke.append(sm)

	# --- Chispas: estelas finas orientadas a su velocidad ---
	var streak := BoxMesh.new()
	streak.size = Vector3(0.035, 0.22, 0.035)
	streak.material = _unshaded(Color.WHITE, true)
	var spark_scale := Curve.new()
	spark_scale.add_point(Vector2(0, 1))
	spark_scale.add_point(Vector2(1, 0.2))
	for p in model.rear_wheel_points:
		var s := CPUParticles3D.new()
		s.mesh = streak
		s.amount = 40
		s.lifetime = 0.32
		s.emitting = false
		s.local_coords = false
		s.position = p + Vector3(0, 0.05, 0.2)
		s.particle_flag_align_y = true
		s.direction = Vector3(0, 0.7, 1)
		s.spread = 40.0
		s.initial_velocity_min = 3.5
		s.initial_velocity_max = 7.5
		s.gravity = Vector3(0, -16, 0)
		s.scale_amount_min = 0.6
		s.scale_amount_max = 1.4
		s.scale_amount_curve = spark_scale
		model.add_child(s)
		_sparks.append(s)
		# Destello en la rueda
		var flare := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		var fm := _unshaded(Color.WHITE, true, radial_texture())
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material = fm
		flare.mesh = q
		flare.position = p + Vector3(0, 0.18, 0.1)
		flare.visible = false
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(flare)
		_flares.append(flare)

	# --- Turbo: llamas cónicas + fuego ---
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.1
	cone.height = 0.7
	cone.radial_segments = 7
	cone.rings = 1
	cone.material = _unshaded(Color(1.0, 0.5, 0.1, 0.8), true)
	var inner := CylinderMesh.new()
	inner.top_radius = 0.0
	inner.bottom_radius = 0.05
	inner.height = 0.32
	inner.radial_segments = 6
	inner.rings = 1
	inner.material = _unshaded(Color(1.0, 0.95, 0.6, 0.95), true)
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = 0.06
	fire_mesh.height = 0.12
	fire_mesh.radial_segments = 6
	fire_mesh.rings = 3
	fire_mesh.material = _unshaded(Color.WHITE, false)   # alfa normal: no satura a blanco
	var fire_ramp := Gradient.new()
	fire_ramp.set_color(0, Color(1.0, 0.85, 0.35, 0.9))
	fire_ramp.add_point(0.35, Color(1.0, 0.42, 0.08, 0.75))
	fire_ramp.set_color(fire_ramp.get_point_count() - 1, Color(0.5, 0.12, 0.08, 0.0))
	for p in model.exhaust_points:
		var holder := Node3D.new()
		holder.position = p + Vector3(0, 0, 0.05)
		holder.rotation_degrees = Vector3(90, 0, 0)   # cono hacia +Z (atrás)
		model.body_pivot.add_child(holder)
		for m: Mesh in [cone, inner]:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.position = Vector3(0, (m as CylinderMesh).height * 0.5, 0)  # base en el escape
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
		holder.visible = false
		_flame_meshes.append(holder)
		var fp := CPUParticles3D.new()
		fp.mesh = fire_mesh
		fp.amount = 14
		fp.lifetime = 0.2
		fp.emitting = false
		fp.local_coords = false
		fp.position = p
		fp.direction = Vector3(0, 0.15, 1)
		fp.spread = 10.0
		fp.initial_velocity_min = 3.0
		fp.initial_velocity_max = 5.0
		fp.gravity = Vector3(0, 1.5, 0)
		fp.scale_amount_min = 0.7
		fp.scale_amount_max = 1.3
		fp.color_ramp = fire_ramp
		model.body_pivot.add_child(fp)
		_flame_particles.append(fp)

	# --- Polvo de tierra ---
	_dust = CPUParticles3D.new()
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.25
	dust_mesh.height = 0.4
	dust_mesh.radial_segments = 6
	dust_mesh.rings = 3
	dust_mesh.material = SMOKE_MATERIAL
	_dust.mesh = dust_mesh
	_dust.amount = 22
	_dust.lifetime = 0.8
	_dust.emitting = false
	_dust.local_coords = false
	_dust.direction = Vector3(0, 1, 1)
	_dust.spread = 45.0
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 3.0
	_dust.gravity = Vector3(0, -2.5, 0)
	_dust.scale_amount_curve = smoke_scale
	var dust_ramp := Gradient.new()
	dust_ramp.set_color(0, Color(0.72, 0.6, 0.42, 0.8))
	dust_ramp.set_color(1, Color(0.72, 0.62, 0.45, 0.0))
	_dust.color_ramp = dust_ramp
	_dust.position = Vector3(0, 0.15, 1.0)
	model.add_child(_dust)

	# --- Sombra de contacto ---
	_shadow = MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(2.1, 3.1)
	sq.orientation = PlaneMesh.FACE_Y
	var sm2 := _unshaded(Color(0, 0, 0, 0.55), false, radial_texture())
	sm2.render_priority = -1
	sq.material = sm2
	_shadow.mesh = sq
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func _process(delta: float) -> void:
	if kart == null:
		return
	_t += delta
	var planar := Vector3(kart.velocity.x, 0, kart.velocity.z)
	var spd := planar.length()
	var grounded: bool = kart.is_on_floor()
	var lvl: int = kart.drift_level
	var drifting: bool = kart.drifting

	# Humo: derrapando, frenando fuerte o patinando de lado
	var slip := absf(planar.dot(kart.global_transform.basis.x))
	var hard_brake: bool = kart.braking_input > 0.5 and kart.forward_speed > 8.0
	var smoking: bool = grounded and kart.on_road and (drifting or hard_brake or slip > 4.5)
	for p in _smoke:
		p.emitting = smoking

	# Chispas y destellos con el color del nivel de mini-turbo
	var col: Color = LEVEL_COLORS[clampi(lvl, 0, 3)]
	for p in _sparks:
		p.emitting = drifting and grounded and lvl > 0
		p.color = col
	for f in _flares:
		f.visible = drifting and grounded and lvl > 0
		if f.visible:
			var pulse := 0.8 + 0.35 * sin(_t * 40.0)
			f.scale = Vector3.ONE * (0.6 + 0.25 * lvl) * pulse
			(f.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(col, 0.9)

	# Turbo
	var boosting: bool = kart.boost_time > 0.0
	for h in _flame_meshes:
		h.visible = boosting
		if boosting:
			var flick := 0.8 + 0.3 * sin(_t * 55.0 + h.position.x * 9.0) + randf() * 0.15
			h.scale = Vector3(1.0, flick, 1.0)
	for p in _flame_particles:
		p.emitting = boosting

	_dust.emitting = (not kart.on_road) and grounded and spd > 4.0

	# Sombra de contacto: pegada al suelo, se encoge y aclara al saltar
	var h := maxf(kart.global_position.y, 0.0)
	_shadow.global_position = Vector3(kart.global_position.x, 0.06, kart.global_position.z)
	_shadow.global_rotation = Vector3(0, kart.global_rotation.y, 0)
	var s := clampf(1.0 - h * 0.5, 0.5, 1.0)
	_shadow.scale = Vector3(s, 1, s)
