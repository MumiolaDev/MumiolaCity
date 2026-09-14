# MumiolaCity — Checklist de implementación

> Complementa [`SCRIPTS.md`](SCRIPTS.md) (el mapa de los 32 scripts, más las once clases de datos que ese documento lista sin detallar), [`SISTEMAS.md`](SISTEMAS.md) (cómo se comunican entre sí y qué decisiones faltan cerrar), [`CLASES.md`](CLASES.md) (la firma de cada clase) y [`GDD.md`](GDD.md). Este documento sí es un plan de trabajo: se va llenando a medida que se implementa cada script, en el mismo orden de `SCRIPTS.md`.
>
> **Formato por script:** **Definir** (decisiones de diseño a cerrar antes de escribir código — cambiarlas después de implementado sale caro) → **Implementar** (qué construir) → **Verificar** (cómo comprobar, con tus propios ojos o con un print, que quedó bien antes de pasar al siguiente). "Listo para el siguiente script" es el criterio de salida de cada bloque.
>
> Por ahora se detalla en profundidad **solo el primer script** (`IsoGrid`), que es el que estás por empezar. El resto de fase 1 se deja como un adelanto liviano de qué se viene, y se detalla igual de a fondo cuando llegue su turno — hacerlo ahora para los 32 sería trabajo especulativo: varias de esas decisiones (ej. cómo exactamente `PlayerController` habla con `IsoGrid`) se van a terminar de cerrar recién al implementar lo anterior, no antes.

---

## 1. `IsoGrid`

**Decisión de base:** `IsoGrid extends TileMapLayer` (Godot 4.3+; `TileMap` con una sola capa en 4.x anteriores a la 4.3), no `extends Node`. Godot ya trae un nodo hecho para pintar y proyectar una grilla isométrica — reimplementar esa proyección a mano sería reinventar algo que el motor resuelve mejor. Este script se apoya en `TileMapLayer` para todo lo visual/geométrico y **solo** agrega lo que Godot no sabe de por sí: qué `WorldObject` ocupa cada celda.

### Definir

1. **Tile Set con forma isométrica.** Se crea como recurso en el editor de Godot (`TileSet` → *Tile Shape* = *Isometric*), no en código. Necesitás al menos 1 tile placeholder (un rombo de color plano alcanza) para poder pintar y probar.
2. **Tamaño de tile.** Se configura en ese mismo `TileSet` (propiedad *Tile Size*). Depende en última instancia del pipeline de arte de Blender (GDD §7), que todavía no existe — arrancá con un placeholder de proporción isométrica estándar 2:1, ej. `64×32`, y ajustalo cuando tengas el primer sprite real exportado.
3. **Tamaño lógico de una sala en celdas**, para saber hasta dónde se puede construir — ej. `Vector2i(12, 12)` como placeholder. Esto es independiente de cuánto piso pintes visualmente: podés pintar más piso del que es "área construible". El tamaño real de la parcela es una decisión de fase 4 (§6 GDD), no de este script.
4. **Convención de coordenadas de celda.** `Vector2i(columna, fila)` — la misma que va a devolver `local_to_map()` de `TileMapLayer`, así que no hay una fórmula propia que inventar ni que se pueda desalinear con el motor.
5. **Cómo se representa la ocupación** (esto sí es tuyo, Godot no lo provee). Un `Dictionary[Vector2i, WorldObject]`, no una matriz 2D de tamaño fijo — así el tamaño de sala puede cambiar sin redimensionar arrays, y una celda vacía simplemente no tiene entrada.
6. **Objetos que ocupan más de una celda** (ej. Mesa de madera, `tamano_grilla: {ancho:2, alto:1}` en `items.json`). Definí que se registran *todas* las celdas que cubre un objeto en el diccionario, todas apuntando a la misma instancia de `WorldObject` — así `esta_libre()` funciona igual sin importar el tamaño del objeto consultado.
7. **Profundidad visual (y-sort) de los objetos** (no de los tiles — eso ya lo resuelve `TileMapLayer` con su propio `y_sort_enabled`). Para que `WorldObject` se ordene bien contra el piso y entre sí, agrupalos bajo un nodo padre con `Y Sort Enabled` activado, en vez de calcular `z_index` a mano.

### Implementar

- `IsoGrid extends TileMapLayer` (componente, sin escena propia — vive como hijo dentro de la escena de `RoomController`, con un `TileSet` isométrico asignado en el inspector).
- Export propio (además de lo que ya trae `TileMapLayer`): `@export var grid_size: Vector2i = Vector2i(12, 12)` — el límite lógico construible, ver punto 3 de "Definir".
- Estado interno: `var _celdas_ocupadas: Dictionary = {}` (clave `Vector2i`, valor referencia a `WorldObject`).
- Funciones propias — las de conversión son wrappers finos sobre lo nativo, las de ocupación son lógica nueva:
  - `mundo_a_celda(pos: Vector2) -> Vector2i` → `return local_to_map(pos)`
  - `celda_a_mundo(celda: Vector2i) -> Vector2` → `return map_to_local(celda)`
  - `celda_valida(celda: Vector2i) -> bool` (dentro de los límites de `grid_size` — esto sí es tuyo, no de `TileMapLayer`)
  - `esta_libre(celda: Vector2i, tamano: Vector2i = Vector2i.ONE) -> bool`
  - `ocupar(celda: Vector2i, tamano: Vector2i, objeto: Node) -> void`
  - `liberar(celda: Vector2i) -> void`
- No hace falta escribir código para "ver" la grilla — pintar unos tiles placeholder en el editor con la herramienta de `TileMapLayer` ya te da la vista isométrica. Eso es directamente el paso de verificación.

### Verificar

1. **Pintar en el editor, no en código.** Con el `TileSet` isométrico asignado, seleccioná `IsoGrid` en el editor y pintá unos 6-8 tiles placeholder a mano con la herramienta nativa de `TileMapLayer`. Si se ven formando el patrón de rombo isométrico sin que hayas escrito una sola línea de proyección, la configuración del `TileSet` está bien — esa es la prueba de que no necesitás fórmula propia.
2. **Sanity check de la conversión:** en un script de prueba, imprimí `celda_a_mundo(Vector2i(0,0))`, `(1,0)`, `(0,1)` y confirmá que los valores devueltos tienen sentido con el tamaño de tile que configuraste (para un tile de `64×32`, ir de `(0,0)` a `(1,0)` debería mover la posición en mundo aproximadamente `32,16` en la diagonal correspondiente). No hace falta derivarlo de memoria — alcanza con que la diferencia entre celdas vecinas sea consistente y proporcional al tile size.
3. **Test de ocupación:** `ocupar(Vector2i(1,1), Vector2i.ONE, objeto_dummy)` → `esta_libre(Vector2i(1,1))` debe dar `false` → `liberar(Vector2i(1,1))` → `esta_libre(Vector2i(1,1))` debe volver a dar `true`.
4. **Test de objeto multi-celda:** `ocupar(Vector2i(3,3), Vector2i(2,1), objeto_dummy)` → tanto `esta_libre(Vector2i(3,3))` como `esta_libre(Vector2i(4,3))` deben dar `false` (mismo objeto, dos celdas).
5. **Test de límites:** `celda_valida(Vector2i(-1, 0))` y `celda_valida(Vector2i(grid_size.x, 0))` deben dar `false`.

**Listo para pasar a `PlayerController` cuando:** pintaste piso placeholder y se ve isométrico correctamente en el editor sin código propio de proyección, y los 4 tests manuales de ocupación/límites pasan. Todavía no hace falta que nada se mueva ni que haya jugador — eso es, literalmente, el siguiente script.

---

## Lo que sigue en fase 1 (adelanto liviano — se detalla a fondo al llegar)

| # | Script | Qué vas a tener que definir antes de implementarlo |
|---|---|---|
| 2 | `PlayerController` | Las acciones del **Input Map** (`mover_izq`, `mover_der`, `interactuar`...) se crean en Project Settings, no en un script — no hay `InputController` propio. Definir también si el movimiento es libre (`velocity` + `move_and_slide()`) o click-to-walk con pathfinding: para el estilo Habbo, lo segundo, apoyado en `AStarGrid2D` alimentado con las celdas ocupadas de `IsoGrid`. |
| 3 | `AvatarComposer` | Necesita al menos un placeholder por capa (cuerpo/torso/piernas) antes de poder probarse — aunque sea un rectángulo de color por capa. Definir los nombres de animación compartidos entre capas (ej. `"caminar"`, `"sentado"`), porque todas las capas se disparan con el mismo nombre. |
| 4 | `RoomController` | Cómo se identifica una sala. Como cada sala **es** un `.tscn`, alcanza con referenciar `PackedScene` directamente; un recurso `RoomDefinition` sería sobre-ingeniería en esta fase. |
| 5 | `WorldObject` | Con qué primer objeto de prueba lo validás — la silla es la candidata obvia, porque ya vas a necesitar `InteractionBehavior` al mismo tiempo. Definir el tamaño de la `CollisionShape2D` del `Area2D` respecto del tile isométrico. |
| 6 | `InteractionBehavior` + `SentarseBehavior` | Nada nuevo que definir — ya quedó resuelto en GDD §6.1. Implementar y verificar sentando al jugador en un `WorldObject` de prueba. |
| 7–10 | `ContextMenuUI`, `HUD`, `GameManager`, `SaveManager` | Se benefician de que ya exista `RoomController` + `WorldObject` funcionando — dejalos para el final de la fase. Los cuatro se apoyan fuerte en nodos nativos (`PopupMenu`, `ProgressBar`, autoload, `ResourceSaver`), así que son más rápidos de lo que parecen. |

> **Nota:** los scripts `InputController` y `CameraController` que aparecían en versiones anteriores de este plan fueron **eliminados** — Godot ya resuelve ambos con el Input Map + el singleton `Input`, y con un `Camera2D` configurado desde el inspector. Ver la tabla "Scripts eliminados" en [`SCRIPTS.md`](SCRIPTS.md).

**Definición de "fase 1 terminada"** (el objetivo real, GDD §9): parado en el área común, tu avatar se mueve por la grilla isométrica, podés cambiar a tu sala privada y volver, y podés sentarte en al menos un objeto interactuable. Todo lo demás de la fase (HUD, guardado) existe para sostener esa experiencia, no es un fin en sí mismo — si esa demo funciona, la fase está lista aunque el resto tenga bordes ásperos.
