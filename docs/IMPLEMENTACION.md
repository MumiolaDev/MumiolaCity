# MumiolaCity — Checklist de implementación

> Complementa [`SCRIPTS.md`](SCRIPTS.md) (el mapa de los 32 scripts, más las once clases de datos que ese documento lista sin detallar), [`SISTEMAS.md`](SISTEMAS.md) (cómo se comunican entre sí y qué decisiones faltan cerrar), [`CLASES.md`](CLASES.md) (la firma de cada clase) y [`GDD.md`](GDD.md). Este documento sí es un plan de trabajo: se va llenando a medida que se implementa cada script, en el mismo orden de `SCRIPTS.md`.
>
> **Formato por script:** **Definir** (decisiones de diseño a cerrar antes de escribir código — cambiarlas después de implementado sale caro) → **Implementar** (qué construir) → **Verificar** (cómo comprobar, con tus propios ojos o con un print, que quedó bien antes de pasar al siguiente). "Listo para el siguiente script" es el criterio de salida de cada bloque.
>
> Por ahora se detalla en profundidad **solo el primer script** (`IsoGrid`), que es el que estás por empezar. El resto de fase 1 se deja como un adelanto liviano de qué se viene, y se detalla igual de a fondo cuando llegue su turno — hacerlo ahora para los 32 sería trabajo especulativo: varias de esas decisiones (ej. cómo exactamente `PersonajeControlador` habla con `IsoGrid`) se van a terminar de cerrar recién al implementar lo anterior, no antes.

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

Los tests 3 a 6 viven en **`escenas/mundo/test/test_isogrid.gd`**: un `Node3D` con ese script, una instancia de `IsoGrid.tscn` como hija con suelo pintado, y el export `grid` apuntando a ella. Se corre con **F6** y reporta por consola. **El script y su escena no se versionan** (`.gitignore`): dependen de cómo esté pintada la sala de prueba de cada máquina y no corren en ningún CI — lo que se versiona es este procedimiento. Usá `WorldObject.new()` como objeto de mentira y no un `Node3D`: `ocupar()` tipa el parámetro como `WorldObject`, y el stub ya existe aunque esté vacío.

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
| 6 | `InteractionBehavior` + `SentarseBehavior` | Nada nuevo que definir — ya quedó resuelto en GDD §6.1. Implementar y verificar sentando al jugador en un `WorldObject` de prueba. |
| 7–10 | `ContextMenuUI`, `HUD`, `GameManager`, `SaveManager` | Se benefician de que ya exista `RoomController` + `WorldObject` funcionando — dejalos para el final de la fase. Los cuatro se apoyan fuerte en nodos nativos (`PopupMenu`, `ProgressBar`, autoload, `ResourceSaver`), así que son más rápidos de lo que parecen. |

> **Nota:** los scripts `InputController` y `CameraController` que aparecían en versiones anteriores de este plan fueron **eliminados** — Godot ya resuelve ambos con el Input Map + el singleton `Input`, y con una `Camera3D` ortográfica colgada de un pivote, configurada desde el inspector. Ver la tabla "Scripts eliminados" en [`SCRIPTS.md`](SCRIPTS.md).

**Definición de "fase 1 terminada"** (el objetivo real, GDD §9): parado en el área común, tu avatar se mueve por la grilla isométrica, podés cambiar a tu sala privada y volver, y podés sentarte en al menos un objeto interactuable. Todo lo demás de la fase (HUD, guardado) existe para sostener esa experiencia, no es un fin en sí mismo — si esa demo funciona, la fase está lista aunque el resto tenga bordes ásperos.
