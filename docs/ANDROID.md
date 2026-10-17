# Instalar el APK de prueba en Android

GitHub compila automáticamente un **APK de prueba** cada vez que se suben cambios
(`.github/workflows/android.yml`) y lo publica en la página de *Releases* del repositorio.

## Requisitos

- Android 7.0 o superior (en la práctica, cualquier móvil de 2017 en adelante).
- Procesador de 64 bits (arm64). Casi todos los móviles actuales lo son.
- Unos 100 MB libres.
- El juego usa OpenGL ES 3.0 (renderizador *Compatibility* de Godot).

## Pasos

1. **Descarga el APK desde el móvil.** Abre en el navegador del móvil:
   **<https://github.com/Erre84/Super-Barrio-Kart-3D./releases/tag/apk-prueba>**
   y pulsa en **`SuperBarrioKart3D.apk`** (≈ 28 MB).
   *Si estás en el PC, descárgalo y pásalo al móvil por cable, Drive, correo o Telegram.*
2. **Ábrelo** desde la notificación de descarga o desde la app *Archivos* → *Descargas*.
3. Android avisará de que la app viene de una **fuente desconocida**. Pulsa **Ajustes** y
   activa **"Permitir de esta fuente"** para el navegador o la app de archivos que estés usando.
   Vuelve atrás.
4. Pulsa **Instalar**. Si *Google Play Protect* muestra un aviso, elige
   **"Más detalles" → "Instalar de todas formas"**. Es normal: el APK está firmado con
   una clave de depuración, no con una de tienda.
5. Abre **Super Barrio Kart 3D**. Se pone en horizontal, a pantalla completa, y los botones
   táctiles aparecen solos.

### Actualizar a una versión nueva

Descarga el APK nuevo de la misma página e instálalo encima: Android lo actualiza sin borrar nada
(todos los APK de prueba se firman con la misma clave de depuración, `tools/android/debug.keystore`).
Si alguna vez da un error de "firma distinta", desinstala la versión anterior y vuelve a instalar.

> La clave de depuración es pública a propósito: sirve solo para pruebas. Para publicar en
> Google Play habrá que crear una clave de publicación privada y guardarla como secreto.

## Cómo se juega en el móvil

| Zona | Botón | Acción |
|---|---|---|
| Pulgar izquierdo | ◀ ▶ | Girar (desliza el dedo entre ambos sin levantarlo) |
| | ATRÁS | Mirar hacia atrás mientras lo mantienes |
| Pulgar derecho | ACEL | Acelerar |
| | FRENO | Frenar y, parado, marcha atrás |
| | DERRAPE | Mantener + girar = derrape; soltar = mini-turbo |
| | TURBO | Turbo cuando la barra pone "¡LISTO!" |
| Arriba | II | Pausa |

Para derrapar: mantén **ACEL**, pulsa **DERRAPE** y gira con **◀** o **▶**. Mientras derrapas,
girar hacia la curva la cierra; girar hacia fuera (contravolante) la abre sin perder el derrape.

## Si algo va mal

- **Pantalla negra o cierre al abrir**: el móvil puede no soportar OpenGL ES 3.0. Cuéntame el
  modelo.
- **Va a tirones**: dime el modelo del móvil. El primer paso sería reducir las sombras y los
  edificios lejanos en la configuración para móviles.
- **Los botones quedan en mala posición o son pequeños**: haz una captura y envíamela.

## Compilar el APK tú mismo (opcional)

Con Godot 4.5, las plantillas de exportación, el SDK de Android y Java 17 instalados:
**Proyecto → Exportar → Android → Exportar proyecto** (el ajuste de exportación ya está en
`export_presets.cfg`). La guía oficial está en
<https://docs.godotengine.org/es/4.x/tutorials/export/exporting_for_android.html>.
