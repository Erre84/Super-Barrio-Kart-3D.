#!/usr/bin/env bash
# Pruebas automáticas de Super Barrio Kart 3D.
#
# Uso:
#   GODOT=/ruta/a/godot ./tools/run_tests.sh            # compila + vuelta automática (sin ventana)
#   GODOT=/ruta/a/godot ./tools/run_tests.sh --shots    # además, capturas de pantalla (necesita GPU o Xvfb)
#
# Qué comprueba:
#   1. Que el proyecto se importa y todos los scripts compilan sin errores.
#   2. Casos concretos de física (tests/physics_tests.gd): sin autocorrección, giro simétrico,
#      derrape natural por pérdida de agarre, contravolante, mini-turbo por maniobra y sus
#      trampas (machacar el acelerador, ventana, derrape corto, trompo), encadenado en recta,
#      marcha atrás, punta, turbo, muros, conos y tierra.
#   3. Que un piloto automático (que usa las mismas acciones de entrada que el jugador)
#      completa una vuelta entera, supera 80 km/h y es capaz de ir marcha atrás.
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="test_output"
mkdir -p "$OUT"

echo "== 1/4 Importando proyecto y compilando scripts =="
"$GODOT" --headless --path . --import 2>&1 | tee "$OUT/import.log"
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$OUT/import.log"; then
	echo "FALLO: hay errores de script"
	exit 1
fi

echo "== 2/4 Pruebas de física del kart =="
set +e
"$GODOT" --headless --path . --fixed-fps 60 -s res://tests/physics_tests.gd 2>&1 | tee "$OUT/physics.log"
code=${PIPESTATUS[0]}
set -e
if [ "$code" -ne 0 ] || grep -q "SCRIPT ERROR" "$OUT/physics.log"; then
	echo "FALLO: pruebas de física"
	exit 1
fi

echo "== 3/4 Vuelta automática (física real, sin render) =="
set +e
"$GODOT" --headless --path . --fixed-fps 60 -- --autopilot --timeout=150 2>&1 | tee "$OUT/autopilot.log"
code=${PIPESTATUS[0]}
set -e
if grep -E "SCRIPT ERROR" "$OUT/autopilot.log"; then
	echo "FALLO: errores de script durante la partida"
	exit 1
fi
if [ "$code" -ne 0 ]; then
	echo "FALLO: el piloto automático no completó la prueba (código $code)"
	exit 1
fi

if [ "${1:-}" = "--shots" ]; then
	echo "== 4/4 Capturas de pantalla =="
	"$GODOT" --path . --resolution 1280x720 -s res://tests/showcase.gd -- --out="$PWD/$OUT/showcase"
	"$GODOT" --path . --resolution 1280x720 --fixed-fps 30 -- --autopilot --shots="$PWD/$OUT/race"
	echo "Capturas en $OUT/showcase y $OUT/race"
else
	echo "== 4/4 Capturas omitidas (usa --shots) =="
fi
echo "OK: todas las pruebas pasaron"
