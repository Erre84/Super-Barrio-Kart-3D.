# Super Barrio Kart 3D

Arcade de karts **poligonal** para **PC y Android**, hecho con **Godot 4** y **GDScript**.
Proyecto independiente que sucede a *Super Barrio Kart v16* (2D): mismo concepto, ambiente
urbano y circuito de **El Prat de Llobregat**, ahora en 3D real.

> **Versión 0.1.0 — primera versión jugable.** Un circuito, un kart y un piloto.
> Todavía no hay rivales, ni objetos/poderes, ni el resto de personajes.

![Carrera en El Prat](docs/img/carrera.png)

## Qué incluye

| | |
|---|---|
| **Kart low-poly** | Chasis, pontones, alerón, motor con escapes, volante y ruedas que giran y se orientan. Todo es geometría 3D facetada (sin sprites). |
| **Piloto chibi** | Cabeza grande, ojos con iris y brillo, gorra hacia atrás, sudadera con capucha. Gira la cabeza hacia la curva. Colores configurables. |
| **Circuito "El Prat"** | ~1 km: recta de meta, curva de 90°, calle con obras, chicane, avinguda con isletas de palmeras, una "ese" y vuelta a meta. Plaza de la Carxofa, bloques de pisos con persianas y toldos, palmeras, pinos piñoneros, farolas, marquesinas, vallas, torre de control y aviones aterrizando. |
| **Conducción arcade** | Aceleración, frenada, marcha atrás, derrape con saltito, mini-turbos (azul → naranja → morado), turbo con barra recargable, pads aceleradores, salida perfecta. |
| **Sin ayudas** | La dirección solo responde a tu entrada: nada gira el kart por ti ni frena antes de las curvas. |
| **Efectos** | Humo de neumáticos, chispas de derrape por nivel, llamas de turbo, polvo fuera de pista, vibración de cámara al chocar. |
| **Colisiones** | Muros New Jersey, isletas, barreras de obra y bolardos (fijos), conos que salen volando. Salirse al arcén de tierra frena. |
| **Cámara** | Tercera persona detrás del kart, FOV dinámico, botón para **mirar atrás**. |
| **Controles** | Teclado, mando y pantalla táctil multitáctil (Android). |
| **HUD** | Velocímetro, vuelta X/3, cronómetro, mejor vuelta, barra de turbo, nivel de mini-turbo, minimapa, cuenta atrás, pausa. |
| **Renderizador** | `Compatibility` (OpenGL 3 / OpenGL ES 3): funciona en casi cualquier PC y móvil. |

| | |
|---|---|
| ![Kart y piloto](docs/img/kart_frente.png) | ![Vista aérea](docs/img/circuito_aereo.png) |
| ![Mirar atrás](docs/img/mirar_atras.png) | ![Controles táctiles](docs/img/controles_tactiles.png) |

## Cómo ejecutarlo

1. Instala **Godot 4.5** (versión estándar, no hace falta la de .NET): <https://godotengine.org/download>
2. Abre Godot → **Importar** → selecciona `project.godot` de este repositorio.
3. Pulsa **F5** (o el botón ▶ "Ejecutar proyecto").

La primera vez Godot tarda unos segundos en importar. No hay recursos que descargar: toda la
geometría se genera al arrancar.

Desde terminal:

```bash
godot --path .                     # jugar
GODOT=godot ./tools/run_tests.sh   # pruebas automáticas
godot --path . -- --touch          # jugar mostrando los controles táctiles en PC
```

## Controles

| Acción | Teclado | Mando (Xbox / PlayStation) | Táctil |
|---|---|---|---|
| Acelerar | `W` / `↑` | `A` / `✕` o gatillo `RT` / `R2` | ACEL |
| Frenar / marcha atrás | `S` / `↓` | `B` / `○` o gatillo `LT` / `L2` | FRENO |
| Girar | `A` `D` / `←` `→` | Stick izquierdo (analógico) o cruceta | ◀ ▶ |
| Derrapar (saltito) | `Espacio` / `Shift` | `RB` / `R1` o `LB` / `L1` | DERRAPE |
| Turbo | `E` / `Ctrl` | `X` / `□` | TURBO |
| Mirar atrás | `Q` / `C` | `Y` / `△` | ATRÁS |
| Reaparecer en pista | `R` | `Back` / `Select` | — |
| Pausa | `Esc` / `P` | `Start` | II |
| Mostrar/ocultar controles táctiles | `F3` | — | — |

En Android los controles táctiles aparecen solos. En PC puedes activarlos con `F3` y usarlos
con el ratón para probarlos. Las teclas usan la posición física, así que funcionan igual con
teclado español, francés, etc.

### Cómo se conduce

- **Girar** solo hace lo que tú indicas. A más velocidad el giro es algo menos brusco, pero
  nunca hay corrección automática.
- **Derrape:** pulsa derrape y gira (o gira y pulsa). El kart da un saltito, se cruza y
  desliza. Mientras derrapas, girar **hacia** la curva la cierra y girar **hacia fuera** la abre.
  Cuanto más aguantes, más carga:
  azul (~1 s) → naranja (~2 s) → morado (~3 s). Suelta para el **mini-turbo**.
- **Turbo:** la barra se recarga sola (≈9 s) y los mini-turbos la rellenan un poco.
- **Salida perfecta:** acelera justo cuando la cuenta atrás va a llegar a 0.
- **Pads naranjas** con flechas: aceleradores.
- Salirse a la **tierra** del arcén frena mucho; los **muros** frenan según lo frontal del golpe.

## Estructura del proyecto

```
project.godot              Configuración (renderer Compatibility, 1280x720, horizontal)
export_presets.cfg         Presets de exportación: Android, Windows, Linux
scenes/
  main.tscn                Escena principal (carrera)
  kart.tscn                Kart del jugador (CharacterBody3D)
  track_el_prat.tscn       Circuito de El Prat
  hud.tscn                 Interfaz
materials/                 Materiales low-poly (color por vértice, luminoso, partículas)
scripts/
  core/input_setup.gd      Mapa de controles (teclado + mando) registrado por código
  core/mesh_builder.gd     Generador de mallas low-poly facetadas
  kart/kart.gd             Física arcade, derrape, turbos, colisiones, efectos
  kart/kart_model.gd       Modelo 3D del kart y del piloto chibi
  kart/chase_camera.gd     Cámara trasera y "mirar atrás"
  track/track_el_prat.gd   Trazado, asfalto, muros, obstáculos, ciudad
  track/props.gd           Edificios, palmeras, farolas, alcachofa, avión...
  track/airplane.gd        Aviones aterrizando
  ui/hud.gd                Velocímetro, vueltas, minimapa, pausa
  ui/touch_controls.gd     Botones táctiles multitáctiles
  game/race.gd             Lógica de carrera y ambiente
tests/
  physics_tests.gd         Pruebas de física (dirección, derrape, muros, conos...)
  autopilot.gd             Piloto automático para pruebas (usa las acciones reales)
  showcase.gd              Capturas de presentación
tools/run_tests.sh         Ejecuta todas las pruebas
docs/PRUEBAS.md            Qué se ha probado, resultados y lista para probarlo tú
.github/workflows/         Pruebas automáticas en GitHub Actions
```

### Por qué la geometría se genera por código

Los modelos (kart, piloto, edificios, palmeras...) se construyen con `mesh_builder.gd` a partir
de primitivas facetadas con color por vértice. Son mallas 3D reales (`ArrayMesh`), con
sombras e iluminación, pero así esta primera versión no depende de archivos de Blender, pesa
muy poco y cada pieza se puede retocar cambiando números. Cuando haya diseños definitivos se
pueden sustituir por modelos `.glb` sin tocar la física.

### Retocar cosas

- **Manejo:** parámetros exportados en `scripts/kart/kart.gd` (velocidad, agarre, giro,
  derrape, turbo).
- **Trazado:** mueve los puntos de `CONTROL_POINTS` en `scripts/track/track_el_prat.gd`;
  asfalto, muros, bordillos, aceras y edificios se regeneran solos.
- **Colores del kart y del piloto:** diccionario `style` en `scripts/kart/kart_model.gd`.

## Exportar a Android

1. En Godot: **Editor → Administrar plantillas de exportación** → descargar.
2. Instala el SDK de Android y configura su ruta en **Editor → Configuración del editor →
   Exportar → Android** ([guía oficial](https://docs.godotengine.org/es/4.x/tutorials/export/exporting_for_android.html)).
3. **Proyecto → Exportar → Android** (el preset ya está creado: arm64, pantalla completa,
   horizontal). Para probar rápido con el móvil conectado por USB usa el botón de
   *despliegue en un clic* de la barra superior del editor.

## Hoja de ruta (siguientes entregas)

- Adaptar los diseños de los personajes de *Super Barrio Kart v16* (esta versión usa un
  piloto provisional; los colores están centralizados para cambiarlo).
- Rivales con IA, posiciones y parrilla completa.
- Objetos/poderes del barrio.
- Sonido y música.
- Más tramos de El Prat y menú principal.
