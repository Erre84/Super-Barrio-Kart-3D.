# Corredores con modelos 3D generados desde las láminas (imagen → 3D)

Los modelos hechos a mano en código no alcanzan el nivel ni el parecido que queremos. Los
corredores pasan a generarse con una herramienta de **imagen a 3D** (Meshy, Tripo...) a
partir de sus láminas, y Claude los integra en el juego: los monta en su kart, los anima
(volante, cabeza, suspensión) y los aligera para Android.

## Qué hay que generar por corredor

Dos modelos separados (así el piloto se puede animar y el kart tiene ruedas que giran):

| Archivo | Qué es | Cómo |
|---|---|---|
| `<id>_piloto.glb` | El personaje **de pie**, cuerpo entero, **con esqueleto** (auto-rig) | Imagen a 3D + Rig |
| `<id>_kart.glb` | El kart **sin piloto** | Imagen a 3D (sin rig) |

## Paso 1 · Preparar las imágenes (ChatGPT u otro generador de imágenes)

Las herramientas de 3D funcionan mejor con **una sola figura, entera, sobre fondo liso**.

**Piloto.** Sube la lámina del corredor y pide:

> Dibuja a este mismo personaje de cuerpo entero, de pie, de frente, en pose A (brazos
> rectos y algo separados del cuerpo, piernas ligeramente abiertas), con la misma cara,
> ropa, peinado y estilo. Fondo blanco liso, sin texto, sin sombras, sin otros objetos.

**Kart.** Sube la lámina o los sprites del kart y pide:

> Dibuja solo este mismo kart, sin piloto, en vista tres cuartos desde delante, con todos
> sus detalles y colores. Fondo blanco liso, sin texto, sin sombras.

Si una lámina ya trae al personaje de pie (Dami, Giovanni, Exito, Frutero, Paulo, Badía,
Rulo, Arko, Masstone, Nylo, Dicc), puedes recortar esa figura y usarla directamente.

## Paso 2 · Generar el 3D (ejemplo con Meshy)

1. **Image to 3D** → sube la imagen del piloto. Activa la textura. Si ofrece elegir pose,
   elige **A-pose** o **T-pose**.
2. Cuando esté, pulsa **Rig / Animate** (auto-rigging de humanoide).
3. **Download → GLB** (si pregunta, con texturas; tamaño moderado, unos 10.000-30.000
   triángulos es suficiente: Claude lo reduce después si hace falta).
4. Repite con la imagen del kart (sin rig) y descárgalo en **GLB**.

En el plan gratuito de Meshy (100 créditos al mes) los modelos se publican con licencia
CC BY 4.0: se pueden usar citando la autoría (se añadirá en los créditos del juego).

## Paso 3 · Pasárselos a Claude

Adjunta en el chat los dos `.glb` de cada corredor (o un `.zip` con varios). Claude:
- los coloca en `assets/racers/<id>/`,
- sienta al piloto en el kart y le pone las manos en el volante,
- separa las ruedas para que giren y viren,
- conserva las animaciones del juego (volante, mirar atrás, inclinación en curva, cara al
  derrapar si el modelo lo permite),
- mide triángulos y llamadas de dibujo y lo aligera para Android,
- saca capturas comparándolo con la lámina.

## Orden recomendado

1. **Dami** (prueba: tiene pose de pie y hoja del kart en varias vistas).
2. Según cómo quede, el resto.

| Corredor | Lámina de partida para el piloto | Lámina de partida para el kart |
|---|---|---|
| Zule | `01_ZULE_oxygen_kart_referencia.png` (no hay pose de pie: pedir al generador) | `01_ZULE_kart_humo_extra.png` |
| Giovanni | `02_GIOVANNI_lakers_referencia.png` (recuadro de pie) | `02_GIOVANNI_lakers_referencia.png` |
| Exito | `03_EXITO_aerosol_referencia.png` (figura de pie) | `03_EXITO_aerosol_referencia.png` |
| Nylo | `nylo_referencia_aprobada.png` | `04_NYLO_hueso_vertical_atlas_reciente.png` |
| Badía | `05_BADIA_mando_playstation_atlas.png` (figura de pie) | la misma |
| Rulo | `06_RULO_microfono_atlas_reciente.png` (figura de pie) | la misma |
| Arko | `arko_referencia_aprobada.png` (figura de pie) | `07_ARKO_porro_encendido_vertical_atlas_reciente.png` |
| Masstone | `08_MASSTONE_libro_alado_atlas.png` (figura de pie) | la misma |
| Paulo | `09_PAULO_bandera_chile_atlas.png` (figura de pie) | `PAULO_MODELO_DEFINITIVO_6_VISTAS.png` |
| José Mari | `josemari_referencia_aprobada.png` (no hay pose de pie: pedir al generador) | la misma |
| Rober | `rober_referencia_aprobada.png` (no hay pose de pie: pedir al generador) | la misma |
| Dicc | `dicc_referencia_aprobada.png` (figura de pie) | la misma |
| Frutero | `el_frutero_estilo_y_confianza.png` | `el_frutero_en_su_kart_retro.png` |
| Dami | `hoja_de_poses_de_dami_y_su_kart_*.png` (figura de pie, a la izquierda) | la misma |
