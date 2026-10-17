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

## Resultados de la v0.2 (Godot 4.5 estable, Linux)

| Prueba | Resultado |
|---|---|
| Importación y compilación de todos los scripts | ✅ sin errores |
| 23 pruebas de física (`tests/physics_tests.gd`) | ✅ 23/23 |
| Vuelta completa con el piloto automático | ✅ 29,7 s, 0 reapariciones, 4 roces |
| Render real con Compatibility (OpenGL 3.3 por software) | ✅ capturas en `docs/img/v0.2/` |
| APK de Android compilado en GitHub Actions | ✅ 27,9 MB, se descarga de la release `apk-prueba` |
| Manifiesto del APK | ✅ minSdk 24 (Android 7.0), targetSdk 35, OpenGL ES 3.0, horizontal, arm64 |

**Pruebas de dirección nuevas en la v0.2:**

```
OK  giro a la izquierda — 1.06 rad, 11.2 m a la izquierda
OK  giro a la derecha — 1.06 rad, 11.2 m a la derecha
OK  izquierda y derecha simétricas — diferencia 0.0000 rad / 0.000 m
OK  sin freno automático en curva — conserva 100% / 100% de la velocidad con gas a fondo
OK  al soltar, el volante vuelve en <0,15 s — giro residual 0.0000 rad/s
OK  después sigue recto (sin autocorrección) — 0.00000 rad en 1 s
OK  derrape progresivo: el ángulo crece — 0.06 → 0.25 → 0.48 rad (0,05 s / 0,17 s / 0,52 s)
OK  derrape progresivo: el giro crece — 1.31 → 2.50 rad/s
OK  derrape sin saltos bruscos — cambio máximo por fotograma 0.0267 rad (límite 0.0272)
OK  contravolante abre la curva — giro cerrar 2.52 / neutro 1.55 / contravolante 0.58 rad/s
OK  contravolante reduce el ángulo — deslizamiento 0.48 / 0.32 / 0.16 rad
OK  con contravolante se mantiene el derrape
```

Se mantienen las 11 pruebas de la v0.1: sin autocorrección, marcha atrás, punta, turbo,
mini-turbo morado, muros, choque detectado, conos y tierra.

### Errores encontrados y corregidos en la v0.2

- El piloto automático se quedaba atascado contra una isleta y la reaparición podía dejar
  el kart encima de ella: ahora siempre se reaparece en el carril libre.
- La luz de relleno se dibujaba en el cielo como un "segundo sol" oscuro.
- El río quedaba enterrado bajo el suelo y los bloques lejanos se colocaban encima del aeropuerto.
- Los rótulos de los monumentos estaban girados del revés y no se leían.
- La suspensión podía volverse inestable si un fotograma tardaba mucho, como en un móvil
  lento; ahora se integra en pasos pequeños.
- Las llamas del turbo saturaban a blanco.
- Cada compilación del APK usaba una clave distinta, lo que obligaba a desinstalar para
  actualizar; ahora la clave de depuración es fija.

## Resultados de la v0.1 (histórico)

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

#### Errores encontrados y corregidos gracias a estas pruebas

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
- **Android en un móvil real.** El APK se compila y su manifiesto es correcto, pero **no se
  ha instalado en ningún teléfono**: no se ha comprobado que arranque, ni los FPS, ni el
  tacto real de los botones.
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
- [ ] El derrape entra suave (no da un latigazo) y se asienta en unas décimas de segundo.
- [ ] Durante el derrape, girar hacia fuera (contravolante) abre la curva **sin** salir del derrape.
- [ ] Girar a la izquierda y a la derecha se siente igual.
- [ ] Al soltar la dirección el kart sigue recto y no busca la carretera por su cuenta.
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

**Android** (instalación: [`ANDROID.md`](ANDROID.md))
- [ ] El APK se instala y el juego arranca.
- [ ] Va fluido (si no, apunta el modelo del móvil).
- [ ] El juego arranca en horizontal y a pantalla completa.
- [ ] Los botones táctiles aparecen solos y se pueden pulsar varios a la vez
      (acelerar + girar + derrapar).
- [ ] Se puede deslizar el pulgar entre ◀ y ▶ sin levantarlo.
- [ ] El botón **II** pausa.
