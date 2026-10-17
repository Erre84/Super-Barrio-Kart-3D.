# Derrape natural y mini-turbo (v0.3)

No hay botón de derrape. El kart derrapa cuando sus neumáticos **no pueden dar la fuerza
lateral que pide el giro**, esté donde esté: en una curva, en plena recta o al esquivar algo.

## Cómo se hace

1. **Pierde el agarre.** A partir de unos 60 km/h, un **volantazo a fondo** hace que las
   ruedas pierdan adherencia poco a poco: el morro gira, pero el kart sigue yendo hacia
   donde iba y empieza a deslizar de lado. Con giros moderados el kart agarra. A baja
   velocidad, aunque gires a fondo, también agarra.
   - Trucos: **frenar mientras giras** quita agarre atrás y el kart se cruza antes. Un
     **golpe de volante a un lado y luego al otro** (cambio brusco) también lo provoca.
2. **Mantén el derrape.** Con el volante a fondo el kart se sostiene cruzado unos 30°,
   chirriando, echando humo y dejando marcas. La barra de derrape se llena:
   **azul** (0,75 s) → **naranja** (1,25 s) → **morado** (1,9 s).
3. **Contravolantea para enderezar.** Gira hacia el otro lado: el morro vuelve hacia la
   trayectoria y el agarre regresa. Con contravolante se endereza en ~0,7 s. Soltando el
   volante cuesta el doble, unos 1,4 s, porque el kart conserva inercia lateral.
4. **¡Suelta y pisa!** Al quedar recto suena una campanita, aparece **"¡SUELTA Y PISA!"**
   y un anillo amarillo bajo el kart. Tienes **0,45 s** para **soltar el acelerador y volver
   a pisarlo**. Si lo haces: **¡MINI-TURBO!** (onda expansiva y explosión de sonido). Cuanto
   más largo fue el derrape, más dura el impulso: 0,55 / 0,85 / 1,2 s.
   - Puedes soltar un pelín antes de quedar recto (hasta 0,2 s) y también vale.

**Encadenar.** Después de un mini-turbo puedes empezar otro derrape enseguida, también en
recta: volantazo a la derecha → contravolante → suelta y pisa → volantazo a la izquierda…

### Qué NO funciona (a propósito)

| Intento | Resultado |
|---|---|
| Machacar el acelerador sin derrapar | Nada: sin derrape válido no hay ventana |
| Machacar el acelerador durante la ventana | Un solo mini-turbo: cada derrape da **un** intento |
| Derrape muy corto (menos de 0,75 s) | "Demasiado corto": no abre ventana |
| No soltar el acelerador al enderezar | "Suelta el acelerador y vuelve a pisar" |
| Pisar cuando ya pasó la ventana | Sin impulso |
| Cruzarse más de 85° (trompo) | Derrape anulado |
| Chocar fuerte contra un muro derrapando | Derrape anulado |
| Quedarse lento derrapando | Derrape anulado |

## Señales

- **Chirrido** de neumáticos que crece con la deriva: empieza suave al perder agarre y
  chilla en derrape pleno. También al frenar fuerte.
- **Humo** más denso cuanto más cruzado vas.
- **Marcas de goma** en el asfalto. Se quedan durante la carrera, hasta 700 tramos.
- **Chispas** del color del nivel (azul / naranja / morado).
- **Indicador** en pantalla con la deriva en grados y la barra de nivel.
- **Ventana**: campanita, texto "¡SUELTA Y PISA!" con barra de tiempo y anillo amarillo.
- **Mini-turbo**: sonido de impulso, onda expansiva del color del nivel, llamas, golpe de
  cámara y texto.
- **Fallo**: sonido grave corto y un aviso que explica qué ha pasado.

## Física (para ajustar)

Todo está en el inspector del nodo `Kart` (`scripts/kart/kart.gd`):

- **Dirección**: `turn_speed`, `high_speed_steer`, `yaw_response` (con agarre),
  `yaw_response_slide` (inercia del giro al deslizar), `slide_steer` (autoridad del
  volante deslizando, incluido el contravolante).
- **Adherencia**: `grip_peak` (m/s² de aceleración lateral con agarre), `grip_slide`
  (agarre dinámico: más bajo = más inercia lateral), `slip_peak_deg` / `slip_full_deg`
  (forma de la curva de agarre), `slide_min_speed`, `oversteer` y `drift_angle_target`
  (tendencia a cruzarse y ángulo de equilibrio), `flick_grip_loss` /
  `flick_sensitivity` (volantazos), `brake_grip_loss`, `slide_drag`.
- **Mini-turbo**: `drift_enter_deg`, `drift_recover_deg`, `drift_recover_hold`,
  `drift_spin_deg`, `drift_min_time`, `drift_level_times`, `mini_turbo_time`,
  `mini_turbo_speed_mult`, `boost_window`, `release_grace`, `lift_min`.

**Cómo funciona por dentro.** Cada fotograma:
1. La velocidad de giro sigue al volante con inercia.
2. Al girar, la velocidad conserva su dirección, así que aparece **velocidad lateral local**.
3. Los neumáticos la anulan hasta su límite de agarre. Ese límite depende del ángulo de
   deriva: es máximo hasta 4° y cae al agarre dinámico a partir de 14°.
4. Si el giro pide más, la deriva crece de forma progresiva.
5. Mientras desliza, el kart tiende a cruzarse hasta un ángulo de equilibrio, y el
   contravolante lo devuelve.

**Garantías.** No hay ningún código que gire, enderece o frene el kart por el jugador, ni
derrapes preprogramados: todo sale de esas fuerzas. Las pruebas automáticas lo comprueban.

## Valores medidos (pruebas automáticas)

| Situación | Resultado |
|---|---|
| Giro al 60 % a 104 km/h | agarra (0,0° de deriva) |
| Volantazo a fondo en recta a 104 km/h | derrapa desde 0,53 s, hasta 24° y 12 m/s laterales |
| Pérdida de agarre | progresiva: 3° → 11° → 23° en 0,25 / 0,5 / 0,75 s |
| Volante a fondo a 44 km/h | no derrapa |
| Volante a fondo sostenido | derrape estable entre 30° y 34° durante 2 s |
| Enderezar con contravolante / soltando el volante | 0,70 s / 1,35 s |
| Frenar a fondo derrapando | trompo (88°) y derrape anulado |
| Izquierda frente a derecha | idéntico (diferencia 0,000°) |
