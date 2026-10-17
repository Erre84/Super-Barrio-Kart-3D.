extends RefCounted
## Los 14 corredores de Super Barrio Kart (tabla de la v16.3 2D: nombre, kart, colores y
## poderes). Cada corredor modelado en 3D tiene su script en scripts/racers/<id>.gd, que
## hereda el esqueleto animado común de scripts/kart/kart_model.gd.
##
## Los poderes se guardan para la futura integración (todavía no están en el 3D).

const RACERS := [
	{"id": "zule", "name": "ZULE", "kart": "Oxygen Kart (teclado MIDI)", "color": Color("ffd35c"), "accent": Color("e8483f"),
		"powers": ["HUMO", "SOUNDGOODIZER"]},
	{"id": "giovanni", "name": "GIOVANNI", "kart": "Kart Lakers 24", "color": Color("b98cff"), "accent": Color("ffc935"),
		"powers": ["AUTO TUNE", "BOOST"]},
	{"id": "exito", "name": "EXITO", "kart": "Spray Kart", "color": Color("ff7ad9"), "accent": Color("7a3cff"),
		"powers": ["SPRAY CEGADOR", "BOOST"]},
	{"id": "nylo", "name": "NYLO", "kart": "Hueso largo", "color": Color("ffe2a6"), "accent": Color("c98a3c"),
		"powers": ["ESCUDO", "BOOST"]},
	{"id": "badia", "name": "BADÍA", "kart": "Mando PS1", "color": Color("9fc2ff"), "accent": Color("2f5fd0"),
		"powers": ["ESCUDO", "BOOST"]},
	{"id": "rulo", "name": "RULO", "kart": "Micrófono Shure", "color": Color("d6d6d6"), "accent": Color("e23b3b"),
		"powers": ["ESCUDO", "BOOST"]},
	{"id": "arko", "name": "ARKO", "kart": "Hoja de marihuana", "color": Color("ff5d5d"), "accent": Color("ffb347"),
		"powers": ["DUENDE ESCARLI", "BOOST"]},
	{"id": "masstone", "name": "MASSTONE", "kart": "TONE · Libro alado", "color": Color("ffe9a8"), "accent": Color("d8a531"),
		"powers": ["ESCUDO", "BOOST"]},
	{"id": "paulo", "name": "PAULO", "kart": "Bandera de Chile", "color": Color("6fa8ff"), "accent": Color("e5323c"),
		"powers": ["ESCUDO", "BOOST"]},
	{"id": "josemari", "name": "JOSÉ MARI", "kart": "Kart azulgrana (Barça)", "color": Color("4b8bff"), "accent": Color("b52e59"),
		"powers": ["LEÓN", "BOOST"]},
	{"id": "rober", "name": "ROBER", "kart": "Bolígrafo azul", "color": Color("87bbff"), "accent": Color("e0b450"),
		"powers": ["RÍOS DE TINTA", "BOOST"]},
	{"id": "dicc", "name": "DICC", "kart": "Diamante", "color": Color("a3eeff"), "accent": Color("f6c462"),
		"powers": ["TRAPKIMAZIN", "BOOST"]},
	{"id": "frutero", "name": "FRUTERO", "kart": "Gorra Ecko", "color": Color("ffcd29"), "accent": Color("ff6f30"),
		"powers": ["TUTTI FRUTTI", "BOOST"]},
	{"id": "dami", "name": "DAMI", "kart": "Batería roja", "color": Color("f23c4a"), "accent": Color("ffbb23"),
		"powers": ["DRUMS", "BOOST"]},
]

const DEFAULT_ID := "zule"

## Corredores con modelo 3D propio (scripts/racers/<id>.gd). Lista explícita: en la APK
## exportada los .gd se guardan compilados, así que no se comprueba si existe el archivo.
const MODELED := {
	"zule": preload("res://scripts/racers/zule.gd"),
	"dami": preload("res://scripts/racers/dami.gd"),
}


static func ids() -> Array:
	var out := []
	for r in RACERS:
		out.append(r["id"])
	return out


static func info(id: String) -> Dictionary:
	for r in RACERS:
		if r["id"] == id:
			return r
	return RACERS[0]


static func model_path(id: String) -> String:
	return "res://scripts/racers/%s.gd" % id


## ¿Tiene ya modelo 3D propio?
static func is_modeled(id: String) -> bool:
	return MODELED.has(id)


static func modeled_ids() -> Array:
	var out := []
	for id in ids():
		if is_modeled(id):
			out.append(id)
	return out


## Crea el modelo 3D del corredor (o el piloto provisional si aún no tiene).
static func make_model(id: String) -> Node3D:
	if MODELED.has(id):
		return MODELED[id].new()
	return load("res://scripts/kart/kart_model.gd").new()
