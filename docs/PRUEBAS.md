# Pruebas

## Pruebas automáticas

```bash
GODOT=/ruta/a/Godot_v4.5 ./tools/run_tests.sh          # compila + una vuelta automática
GODOT=/ruta/a/Godot_v4.5 ./tools/run_tests.sh --shots  # además, capturas en test_output/
```

También se ejecutan solas en GitHub Actions en cada *push* y *pull request*
(`.github/workflows/pruebas.yml`).

1. **Importación y compilación**: `godot --headless --import` no debe mostrar ningún
   `SCRIPT ERROR`.
2. **Vuelta automática**: `tests/autopilot.gd` conduce el kart pulsando las mismas acciones
   del `InputMap` que un jugador (`accelerate`, `steer_left`, `drift`...). Al terminar imprime
   un resumen JSON y falla si no completa una vuelta, no supera 80 km/h o no es capaz de
   ir marcha atrás. El piloto automático es deliberadamente torpe: roza muros y se sale en
   la "ese". Sirve para detectar roturas, no para medir lo bien que se conduce.
3. **Capturas** (`--shots`): necesitan una GPU o un servidor gráfico virtual (Xvfb).

## Resultados de esta entrega (Godot 4.5 estable, Linux)

Comprobado en un entorno sin pantalla ni GPU, con Godot 4.5 oficial:

| Prueba | Resultado |
|---|---|
| Importación del proyecto, compilación de todos los scripts | ✅ sin errores |
| 11 pruebas de física (`tests/physics_tests.gd`) | ✅ 11/11 |
| Vuelta completa con el piloto automático (física real a 60 Hz) | ✅ ver resumen abajo |
| Render real con el renderizador Compatibility (OpenGL 3.3, Mesa llvmpipe por software) | ✅ capturas en `docs/img/` |
| Marcha atrás | ✅ alcanza la velocidad máxima de marcha atrás (−9 m/s) |
| Derrape y mini-turbos | ✅ el piloto automático encadena varios mini-turbos por vuelta |
| Turbo, pads aceleradores y salida perfecta | ✅ se disparan durante la vuelta |
| Choques con muros | ✅ el kart rebota y pierde velocidad, sin atravesar |

**Pruebas de física** (`tests/physics_tests.gd`):

```
OK  sin autocorrección de dirección — giro sin tocar el volante: 0.00000 rad
OK  marcha atrás — velocidad hacia delante -9.0 m/s
OK  velocidad punta — 104 km/h
OK  turbo supera la punta — 138 km/h con turbo
OK  entra en derrape
OK  mini-turbo morado (nivel 3)
OK  al soltar sale el mini-turbo — ["mini3"]
OK  el muro no se atraviesa — se queda a 10.5 m del eje (muro a 12 m), lanzado a 108 km/h con turbo
OK  se detecta el choque
OK  los conos salen volando — el cono se movió ~8 m
OK  la tierra frena — 57 km/h fuera de pista
```

**Vuelta automática** (resumen impreso por `tests/autopilot.gd`):

```
vuelta: 31.8 s   punta: 138 km/h (con turbo)   choques con muro: 7
mini-turbos: 9   turbos: 4   pads: 2   salida perfecta: sí
fuera de pista: 0 s   reapariciones: 0   marcha atrás: -9 m/s
```

**Capturas reales del juego** (renderizador Compatibility):

| | |
|---|---|
| ![Derrape](img/carrera.png) | ![Mirar atrás](img/mirar_atras.png) |
| ![Avinguda](img/avinguda.png) | ![Controles táctiles](img/controles_tactiles.png) |
| ![Piloto chibi](img/piloto_cara.png) | ![Plaça de la Carxofa](img/plaza_carxofa.png) |

### Errores encontrados y corregidos gracias a estas pruebas

- Los colores de vértice salían con la gamma mal (todo casi blanco): ahora se escriben en
  espacio lineal.
- El derrape hacía perder casi toda la velocidad y nunca pasaba del nivel azul: se cambió a
  un modelo arcade que conserva la velocidad con un ángulo de deslizamiento fijo.
- La normal de los muros llegaba invertida y el choque no se registraba (ni frenaba ni hacía
  vibrar la cámara).
- La capa de botones táctiles medía 0×0 píxeles y no se veía; después, los botones se
  solapaban. Ambas cosas corregidas.
- Los bloques de pisos junto al circuito no se colocaban; el dorsal salía del revés; la cara
  del piloto parecía llevar gafas de sol.

## Lo que NO se ha podido probar aquí

Sé claro con esto antes de dar la versión por buena:

- **Sensación de manejo con manos humanas.** Nadie ha conducido todavía con teclado ni
  mando: solo el piloto automático. Los valores de giro, agarre y derrape son un primer
  ajuste razonable; es muy probable que haya que retocarlos jugando
  (están todos en el inspector del nodo `Kart`).
- **Mando físico.** El mapeo está definido (Xbox/PlayStation estándar vía SDL), pero no se
  ha conectado ningún mando real.
- **Android.** No se ha exportado un APK ni se ha probado en un móvil: el entorno no tenía
  SDK de Android. Los controles táctiles se han revisado visualmente y por código, pero no
  con dedos reales.
- **Rendimiento real.** El render se ha hecho por software (muy lento); no hay medidas de
  FPS en un PC con GPU ni en un móvil. Toda la ciudad son unas pocas mallas grandes; si un
  móvil modesto va justo, lo primero sería reducir sombras y edificios lejanos.
- **Windows/macOS.** Solo se ha ejecutado en Linux.
- **Sonido.** No hay audio en esta versión.

## Lista de comprobación manual (para ti)

**PC, teclado**
- [ ] El juego arranca, se ve la cuenta atrás 3-2-1-¡YA!.
- [ ] Acelerar justo antes del ¡YA! da "¡Salida perfecta!".
- [ ] `A`/`D` giran el kart y, al soltar, el kart sigue recto (no se endereza solo hacia la calle).
- [ ] `S` frena y, parado, va marcha atrás.
- [ ] `Espacio` + giro: saltito, derrape, chispas azul → naranja → morado; al soltar, turbo.
- [ ] Humo de neumáticos al derrapar y al frenar fuerte.
- [ ] `E` con la barra llena: ¡TURBO! y llamas por los escapes.
- [ ] `Q` mantiene la vista hacia atrás.
- [ ] Chocar con un muro frena y hace vibrar la cámara; los conos salen volando.
- [ ] Salirse a la tierra frena y levanta polvo.
- [ ] Contador de vueltas 1/3 → 2/3 → ÚLTIMA VUELTA → ¡META!.
- [ ] `R` devuelve el kart a la pista. `Esc` pausa; "Reiniciar carrera" funciona.

**Mando**
- [ ] Stick izquierdo gira de forma progresiva (analógica).
- [ ] Gatillos aceleran/frenan; `RB`/`LB` derrapan; `X` turbo; `Y` mirar atrás; `Start` pausa.

**Android**
- [ ] El juego arranca en horizontal y a pantalla completa.
- [ ] Los botones táctiles aparecen solos y se pueden pulsar varios a la vez
      (acelerar + girar + derrapar).
- [ ] Se puede deslizar el pulgar entre ◀ y ▶ sin levantarlo.
- [ ] El botón **II** pausa.
