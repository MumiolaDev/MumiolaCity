# MumiolaCity — Checklist de implementación

> Complementa [`SCRIPTS.md`](SCRIPTS.md) (el mapa de los scripts, más las clases de datos que ese documento lista sin detallar), [`SISTEMAS.md`](SISTEMAS.md) (cómo se comunican entre sí y qué decisiones faltan cerrar), [`CLASES.md`](CLASES.md) (la firma de cada clase) y [`GDD.md`](GDD.md). Este documento sí es un plan de trabajo: se va llenando a medida que se implementa cada script, en el mismo orden de `SCRIPTS.md`.
>
> **Formato por script:** **Definir** (decisiones de diseño a cerrar antes de escribir código — cambiarlas después de implementado sale caro) → **Implementar** (qué construir) → **Verificar** (cómo comprobar, con tus propios ojos o con un print, que quedó bien antes de pasar al siguiente). "Listo para el siguiente script" es el criterio de salida de cada bloque.
>
> **La sección 1 (`IsoGrid`) es el registro del primer script y se conserva tal cual**, incluida la parte que ya no se cumple: sirve para ver qué se decidió antes de escribir y qué cambió al escribirlo. Lo que está vigente es lo de acá abajo. El resto de los scripts no se detalló por adelantado a propósito — habría sido trabajo especulativo, porque varias de esas decisiones se terminaron de cerrar recién al implementar lo anterior.

---

## Dónde estamos (25 de septiembre de 2026)

| Fase | Estado |
|---|---|
| 0 — Diseño | cerrada |
| 1 — Sistema base en 3D | terminada y probada |
| 2a — Economía sin interfaz | terminada, 114 comprobaciones; **archivada** con el giro a sandbox |
| 3 — El editor de sala | terminada, criterio cumplido |
| 4 — La interfaz y el flujo | **terminada**, en cinco etapas (U1–U5), criterio cumplido |
| 5 — La interacción fina | siguiente. Ya hechos, de la vieja fase 4: `PoseBehavior` y `LevantarBehavior` |
| 6 — Social y rol · 7 — Estilo visual · 8 — Red | pendientes; la red, con las seis costuras ya puestas |

**Qué trajo la fase 4**, por etapa:

- **U1 — El tema.** `herramientas/ConstructorTema.gd` arma `ui/tema/tema.tres` desde los sprites del pack Flat, que entran escalados x2 con `herramientas/escalar_sprites_ui.py`. Fuentes Pixelify Sans y VT323. Componentes `Ventana` y `Dialogo`.
- **U2 — La consola.** El autoload `Consola` (chat, sistema, error, debug), el registro `Comandos` y la caja de abajo a la izquierda. Se fueron el texto crudo de atajos y los atajos de economía; la ayuda es una ventana (F1).
- **U3 — Salas como documentos.** El autoload `Servidor` —la costura de la red— con `ServidorLocal` detrás. Una sala es `Sala.tscn` más su documento, con id propio, y se carga de a una con `GameManager.ir_a()`, entre un fundido del autoload `Transicion`. La plaza y cinco plantillas de forma son JSON en `data/salas/`.
- **U4 — El navegador.** `NavegadorUI` (públicas, mis salas, crear desde forma) y `BarraJuego`. `puede_editar()` aplica la regla real.
- **U5 — Perfiles.** `MenuInicio` es la escena principal; cada perfil trae su casa y guarda dónde te quedaste. `MenuPausa` (Esc) y `OpcionesUI`.

**Lo que sigue, en la fase 5**, en orden:

1. **`InventoryUI` y colocar desde la mochila jugando.** Hoy levantar un mueble lo manda a la mochila y no hay forma de volver a ponerlo sin el editor. Es lo que cierra el círculo del verbo que ya existe.
2. **`SuperficieBehavior`** (D25, decidida): apoyar cosas sobre mesas y estantes. Le da sentido a los 33 ítems chicos que hoy no tienen verbo.
3. **Un estado genérico por instancia** en `ItemInstance` —abierto, encendido, lleno, sucio— y sobre él `ContenedorBehavior` (`abrir`) y `AlternarBehavior` (`encender`), para que un verbo nuevo sea datos.
4. **Acciones con duración** (una barra de progreso sobre el avatar) y **objetos en la mano** (enganche al hueso, D20).
5. Los verbos pendientes del catálogo: `servir` y `vaciar` en el plato y el bol.

---

## Cómo se verifica

**Los tests sí se versionan, y viven en `mumiola-city/escenas/test/`.** La convención de la sección 1 —escenas de verificación local fuera del repo— valía cuando el único test dependía de cómo estuviera pintada la sala de prueba de cada máquina. Dejó de valer en cuanto hubo reglas que comprobar y no solo conversiones que mirar.

Cada test es un `Node` con un script que se cuelga de `Mundo` y reporta por consola, terminando en una línea `NOMBRE: todo ok` o `NOMBRE: N fallos`. Son veintiuno: `test_camara`, `test_clic_menu`, `test_consola`, `test_documento`, `test_economia`, `test_editor`, `test_fantasma_pieza`, `test_huella_objeto`, `test_huellas`, `test_ir_a_sala`, `test_levantar`, `test_menu_posicion`, `test_mirar`, `test_navegador`, `test_ocupar_bloquear`, `test_perfiles`, `test_poses`, `test_rotacion`, `test_salida_pose`, `test_servidor` y `test_ventana`. `test_perfiles` recorre dos cambios de escena, así que se muda a la raíz del árbol al empezar.

**`test_huellas` tiene tres fallos que vienen de antes de la fase 4** (ya estaban en `837cbd2`): `espacio_puerta` no bloquea su propia celda y la huella no gira con la pieza. Están sin investigar.

**Los tests escriben en `user://`** (salas y perfiles). En la copia donde se corren, conviene agregar a `project.godot`, bajo `[application]`, `config/use_custom_user_dir=true` y `config/custom_user_dir_name="MumiolaCityTest"`, y borrar esa carpeta antes de cada corrida: así no se mezclan con las salas y perfiles de verdad, y cada test arranca sin restos del anterior.

**Muestrario del tema:** `escenas/test/muestra_tema.tscn` pone un control de cada tipo en pantalla. Con `-- --captura=<ruta.png>` guarda una captura y se cierra, que es como se revisa el tema después de regenerarlo.

**Tres cosas que se aprendieron escribiéndolos**, y que se pagan caro si se olvidan:

1. **Una prueba que pasa no siempre prueba lo que decís.** El primer arreglo de «cancelar el menú no debe mandar a caminar» pasó su test y seguía roto en el juego: el test cerraba el menú a mano antes de clickear, y en el juego `_unhandled_input` llega **antes** que `popup_hide`. Verificaba una secuencia que no ocurre nunca.
2. **Esperar por reloj y no por cuadros.** `Lie_Down` dura 3.00 s justos y la ventana corría a ~100 fps, así que contar 300 cuadros se quedaba corto por milésimas y medía al personaje a mitad de la transición. Todas las esperas de animación usan `Time.get_ticks_msec()`.
3. **Un clic perdido sobre la ventana saca al personaje de la pose.** Los tests que miden poses llaman a `set_process_unhandled_input(false)` sobre el jugador.

**Para verificar sin tocar el proyecto abierto:** se copia `mumiola-city/` a un directorio aparte y se corre Godot en headless ahí. Editar `project.godot` desde afuera mientras el editor está abierto es una carrera (**D9**). Para lo que hay que ver —encuadres, poses, alturas— se corre una ventana real fuera de pantalla (`--position 6000,6000`) y se miran los PNG.

---

## 1. `IsoGrid`

**Decisión de base (revisada el 2026-09-15):** `IsoGrid extends Node3D`, con **dos `GridMap` hijos** —`Suelo` y `Paredes`— y escena propia. Reemplaza al `extends TileMapLayer` del plan original, que asumía sprites 2D.

```
IsoGrid (Node3D)        ← el script
├── Suelo   (GridMap)
└── Paredes (GridMap)
```

Con el mundo en 3D, **la proyección isométrica dejó de ser un problema de este nodo**: es el ángulo de la cámara (GDD §7). No hay `TileSet` isométrico que configurar, ni matemática 2:1, ni conversión propia de coordenadas, ni y-sort. El script se apoya en `GridMap` para todo lo geométrico y visual, y **solo** agrega lo que Godot no modela: qué `WorldObject` ocupa cada celda.

### Definir

1. **Tamaño de celda: 1 metro = 1 unidad.** `cell_size = Vector3(1, 1, 1)`. Sale de los modelos: con los KayKit en escala real una silla mide 0.75 m y entra en una celda, una mesa mediana ocupa 2×2 y una cama doble 3×3 — coherente con los `tamano_grilla` de `items.json`. El `Floor` de KayKit mide 4×4 y **no es una baldosa**: es una losa de sala, hay que escalarla a 0.25 para que valga una celda.
2. **Dos `GridMap`, no uno.** Una celda de `GridMap` admite un solo ítem: pintar una pared sobre una celda de suelo la reemplaza y el suelo desaparece. Regla de composición: **suelo por dentro, paredes por fuera**, en el anillo de celdas sin suelo, como en Habbo.
3. **`Node3D` coordinador y no `extends GridMap`.** Colgar el script del suelo haría de las paredes un apéndice de la capa de suelo, cuando son dos vistas de la misma sala. Cuesta un `suelo.` por conversión y deja lugar para una tercera capa sin reorganizar nada.
4. **Convención de coordenadas.** La API pública habla en `Vector2i` (planta del piso); `Vector3i` aparece solo para hablarle a los `GridMap`. Así `celda_origen` (**D3**), los `tamano_grilla` de `items.json` y el `AStarGrid2D` siguen valiendo tal como están escritos.
5. **Cómo se representa la ocupación** (esto sí es tuyo). Un `Dictionary[Vector2i, WorldObject]`, no una matriz de tamaño fijo — así la sala puede cambiar de forma y una celda vacía simplemente no tiene entrada.
6. **Objetos de más de una celda.** Se registran **todas** las celdas que cubre un objeto, todas apuntando a la misma instancia, para que `esta_libre()` funcione igual sin importar el tamaño consultado.
7. **`celda_valida()` pregunta por el suelo, no por un rectángulo.** `suelo.get_cell_item(...) != GridMap.INVALID_CELL_ITEM`. El área caminable pasa a ser *lo que pintaste*, y las salas irregulares o en L salen gratis. Por eso desapareció el `grid_size` del plan original.
8. **Los dos hijos van con transformación en cero**, y el origen de `IsoGrid` es el origen de la sala. `map_to_local()` trabaja en el espacio local del `GridMap`: si alguien mueve un hijo, las conversiones mienten sin dar error. Anotalo como comentario arriba del script.

### Implementar

- `IsoGrid extends Node3D` con escena propia, `@export var suelo: GridMap` y `@export var paredes: GridMap`.
- Estado interno: `var _ocupadas: Dictionary = {}` (clave `Vector2i`, valor `WorldObject`).
- Señal `ocupacion_cambiada(celdas: Array)`, emitida por `ocupar()` y `liberar_objeto()`.
- **El mínimo para poder colocar el primer objeto**, en orden de dependencia:
  - `celda_a_mundo(celda: Vector2i) -> Vector3` → `suelo.map_to_local(Vector3i(celda.x, 0, celda.y))`
  - `mundo_a_celda(pos: Vector3) -> Vector2i` → `suelo.local_to_map()` descartando la Y
  - `celda_valida(celda: Vector2i) -> bool`
  - `celdas_de(origen: Vector2i, tamano: Vector2i) -> Array[Vector2i]` — el helper que expande un 2×1 a sus celdas; tenerlo aparte evita repetir el mismo bucle mal en tres sitios
  - `esta_libre(origen, tamano) -> bool`
  - `ocupar(origen, tamano, obj) -> bool`
- **Inmediatamente después:** `objeto_en(celda)` (lo necesita `ContextMenuUI`), `liberar_objeto(obj)` (recibe el **objeto**, no la celda: un mueble de 2×1 ocupa dos entradas y liberar por celda deja la otra colgada).
- El escenario se pinta con la herramienta nativa del `GridMap` desde el editor. No hace falta código para verlo.

### Verificar

1. **Pintar en el editor.** Con la `MeshLibrary` asignada, pintá un suelo y unas paredes. Si la sala se ve completa y centrada y las paredes calzan sin huecos ni solapes, la escala está bien. **Hacé esto antes de escribir una línea de ocupación:** si no, cualquier bug de escala se te va a disfrazar de bug de ocupación.
2. **Toda pieza mide exactamente una celda (D15).** `GridMap.get_used_cells()` devuelve las celdas donde se *colocó* una pieza, no las que su malla invade, así que una pared de dos metros pintada en una celda bloquea una sola y el personaje la atraviesa por la otra mitad. Las mallas del pack que sobresalían fueron reescaladas a un tile. Lo que abarca varias celdas se pinta celda por celda, y `_validar_piezas()` avisa por consola si aparece una pieza que no cumple.
3. **Sanity check de la conversión:** imprimí `celda_a_mundo(Vector2i(0,0))`, `(1,0)` y `(0,1)` y confirmá que celdas vecinas difieren exactamente en el `cell_size`.
4. **Test de ocupación:** `ocupar(Vector2i(1,1), Vector2i.ONE, dummy)` → `esta_libre(Vector2i(1,1))` da `false` → `liberar_objeto(dummy)` → vuelve a dar `true`.
5. **Test de objeto multi-celda:** `ocupar(Vector2i(3,3), Vector2i(2,1), dummy)` → `esta_libre` da `false` tanto en `(3,3)` como en `(4,3)`; un solo `liberar_objeto(dummy)` libera las dos.
6. **Test de límites:** `celda_valida()` da `false` en una celda donde no pintaste suelo.

Los tests 3 a 6 vivieron en **`escenas/mundo/test/test_isogrid.gd`**, fuera del repo, porque dependían de cómo estuviera pintada la sala de prueba de cada máquina. **Esa convención ya no es la vigente** — ver «Cómo se verifica» más arriba: los tests posteriores sí se versionan, en `escenas/test/`. Usá `WorldObject.new()` como objeto de mentira y no un `Node3D`: `ocupar()` tipa el parámetro como `WorldObject`, y el stub ya existe aunque esté vacío.

El script no usa `assert()` a propósito — corta en el primer fallo y desaparece en las builds de release — y busca las celdas libres en vez de tenerlas escritas, para que repintar la sala no haga fallar un test sin que nada esté roto.

**Listo para pasar a `PersonajeControlador` cuando:** la sala se ve bien en el editor con la cámara isométrica puesta, y los cuatro tests de ocupación y límites pasan. Todavía no hace falta que nada se mueva — eso es, literalmente, el siguiente script.

---

## Lo que sigue en fase 1 (adelanto liviano — se detalla a fondo al llegar)

| # | Script | Qué vas a tener que definir antes de implementarlo |
|---|---|---|
| 2 | `PersonajeControlador` | Las acciones del **Input Map** (`mover_izq`, `mover_der`, `interactuar`...) se crean en Project Settings, no en un script — no hay `InputController` propio. Definir también si el movimiento es libre (`velocity` + `move_and_slide()`) o click-to-walk con pathfinding: para el estilo Habbo, lo segundo, apoyado en `AStarGrid2D` alimentado con las celdas ocupadas de `IsoGrid`. |
| 3 | `AvatarComposer` | Importar las animaciones como **Animation Library**, no como escena — si no, terminás con ocho maniquíes y ninguna animación donde la necesitás. El `AnimationPlayer` se agrega a mano (el maniquí no trae uno) y su `root_node` tiene que resolver el prefijo de las pistas, que en el pack de KayKit es el nodo **por encima** de `Rig_Medium`. Definir también la tabla de nombres lógicos a nombres del pack. |
| 4 | `RoomController` | Cómo se identifica una sala. Como cada sala **es** un `.tscn`, alcanza con referenciar `PackedScene` directamente; un recurso `RoomDefinition` sería sobre-ingeniería en esta fase. |
| 5 | `WorldObject` | Con qué primer objeto de prueba lo validás — la silla es la candidata obvia, porque ya vas a necesitar `InteractionBehavior` al mismo tiempo. La `CollisionShape3D` del `Area3D` no necesita seguir la malla: como la ocupación la lleva `IsoGrid`, un `BoxShape3D` del tamaño de la celda alcanza y es más barato. |
| 6 | `InteractionBehavior` + `PoseBehavior` | Nada nuevo que definir — ya quedó resuelto en GDD §6.1. Implementar y verificar sentando al jugador en un `WorldObject` de prueba. |
| 7–10 | `ContextMenuUI`, `HUD`, `GameManager`, `SaveManager` | Se benefician de que ya exista `RoomController` + `WorldObject` funcionando — dejalos para el final de la fase. Los cuatro se apoyan fuerte en nodos nativos (`PopupMenu`, `ProgressBar`, autoload, `ResourceSaver`), así que son más rápidos de lo que parecen. |

> **Nota:** los scripts `InputController` y `CameraController` que aparecían en versiones anteriores de este plan fueron **eliminados** — Godot ya resuelve ambos con el Input Map + el singleton `Input`, y con una `Camera3D` ortográfica colgada de un pivote, configurada desde el inspector. Ver la tabla "Scripts eliminados" en [`SCRIPTS.md`](SCRIPTS.md).

**Definición de "fase 1 terminada"** (el objetivo real, GDD §9): parado en el área común, tu avatar se mueve por la grilla isométrica, podés cambiar a tu sala privada y volver, y podés sentarte en al menos un objeto interactuable. Todo lo demás de la fase (HUD, guardado) existe para sostener esa experiencia, no es un fin en sí mismo — si esa demo funciona, la fase está lista aunque el resto tenga bordes ásperos.
