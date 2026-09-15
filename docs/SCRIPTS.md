# MumiolaCity — Arquitectura de scripts

> Complementa [`GDD.md`](GDD.md) (especialmente §6.1 Interactividad de objetos y §8 Arquitectura técnica) y el roadmap de fases de `GDD.md` §9. Este documento no es código: es el mapa de qué scripts van a existir, qué hace cada uno, si es una escena propia o un script suelto, qué clase de Godot hereda, un par de funciones clave que debería tener, y de qué otros scripts depende — ordenado por la secuencia en la que conviene implementarlos. Actualizar junto con `GDD.md` si cambia el roadmap o el sistema de interacción.
>
> **Versión navegable (artefacto):** https://claude.ai/code/artifact/5f914cd8-0d3b-437a-981a-0f18a4bb0a82 — mismo contenido que este archivo, con navegación por fase y enlaces cruzados entre scripts. Privado; compartir desde el menú de la página si hace falta. Si este documento cambia, hay que republicar el artefacto para que no quede desactualizado.
>
> **Revisado el 2026-09-15:** el proyecto pasó de sprites 2.5D pre-renderizados a **mundo 3D en tiempo real con cámara ortográfica isométrica** (GDD §7). Solo cambió la capa Mundo — nueve clases pasan a bases 3D y `IsoGrid` se reorganiza sobre dos `GridMap`. Los ocho managers, los once recursos de datos y toda la economía quedaron intactos, que es exactamente lo que compraba la regla de dirección de `SISTEMAS.md` §1.
>
> **Sistemas y decisiones abiertas:** ver [`SISTEMAS.md`](SISTEMAS.md) — cómo se comunican estos scripts entre sí, dónde vive cada dato y las once decisiones (D1–D11) que hay que cerrar antes de escribir el código de cada fase.
>
> **Firma de cada clase:** ver [`CLASES.md`](CLASES.md) — campos `@export`, señales, métodos e invariantes de las 43 clases. Este documento detalla **32**: las otras once son recursos de datos que aparecieron al revisar el diseño y se listan, con su fase y su motivo, en la tabla "Las once clases que esta tabla no detalla" de más abajo.
>
> **Checklist de implementación:** ver [`docs/IMPLEMENTACION.md`](IMPLEMENTACION.md) — qué definir, qué implementar y cómo verificar cada script antes de pasar al siguiente, en el mismo orden de esta tabla.

## Principio rector: no reimplementar lo que Godot ya trae

Antes de escribir un sistema, hay que revisar si el motor ya lo resuelve — y si lo resuelve, heredar de ese nodo o usar esa API en vez de construir uno propio. Se escribe a mano únicamente lo que es **lógica específica de este juego** (inventario, recetas, economía, ocupación de celdas por objetos) o lo que el motor genuinamente no cubre. Por eso cada script de abajo declara explícitamente una línea **Godot nativo**: qué parte le delega al motor y qué parte es código propio. Esta revisión ya eliminó dos scripts que sobraban y corrigió cuatro clases base.

**Convención de tipos** (rol en la arquitectura, GDD §8): **Autoload** — singleton global (`res://autoloads/`). **Resource** — recurso de datos (`res://data/`), `.tres`, sin escena. **Nodo/UI** — nodo instanciable en el árbol de escena (`res://scenes/`).

**Convención de "forma" del script** (ortogonal a lo anterior — si tiene o no una escena propia):
- **Escena (`.tscn`)** — raíz de su propia escena instanciable.
- **Componente** — script suelto que vive como hijo dentro de la escena de otro nodo, sin `.tscn` propio.
- **Autoload** — singleton global, sin escena.
- **Recurso (`.tres`)** — dato o comportamiento, sin escena.

---

## Resumen (orden de implementación)

| # | Script | Tipo | Forma | Extends | Fase |
|---|---|---|---|---|---|
| 1 | `IsoGrid` | Nodo/Escena | Escena | `Node3D` | 1 |
| 2 | `PlayerController` | Nodo/Escena | Escena | `CharacterBody3D` | 1 |
| 3 | `AvatarComposer` | Nodo | Componente | `Node3D` | 1 |
| 3b | `IndicadorCelda` | Nodo | Componente | `MeshInstance3D` | 1 (ayuda de desarrollo) |
| 4 | `RoomController` | Nodo/Escena | Escena | `Node3D` | 1 |
| 5 | `WorldObject` | Nodo/Escena | Escena | `Area3D` | 1 |
| 6 | `InteractionBehavior` (+ `SentarseBehavior`) | Resource | Recurso | `Resource` | 1 |
| 7 | `ContextMenuUI` | UI | Escena | `PopupMenu` | 1 |
| 8 | `HUD` | UI | Escena | `CanvasLayer` | 1 |
| 9 | `GameManager` | Autoload | Autoload | `Node` | 1 |
| 10 | `SaveManager` (mínimo) | Autoload | Autoload | `Node` | 1 |
| 11 | `ItemDefinition` | Resource | Recurso | `Resource` | 2 |
| 12 | `RecipeDefinition` | Resource | Recurso | `Resource` | 2 |
| 13 | `SkillDefinition` | Resource | Recurso | `Resource` | 2 |
| 14 | `ItemInstance` | Resource | Recurso | `Resource` | 2 |
| 15 | `SkillManager` | Autoload | Autoload | `Node` | 2 |
| 16 | `InventoryManager` | Autoload | Autoload | `Node` | 2 |
| 17 | `RecipeManager` | Autoload | Autoload | `Node` | 2 |
| 18 | `TimeManager` | Autoload | Autoload | `Node` | 2 |
| 19 | `GatherableNode` | Nodo/Escena | Escena | `Area3D` | 2 |
| 20 | `CropPlot` | Nodo/Escena | Escena | `GatherableNode` | 2 |
| 21 | `ContenedorBehavior` | Resource | Recurso | `InteractionBehavior` | 2 |
| 22 | `ModifierStack` | Nodo | Componente | `Node` | 2 |
| 23 | `EconomyManager` (básico) | Autoload | Autoload | `Node` | 2 |
| 24 | `InventoryUI` | UI | Escena | `Control` | 3 |
| 25 | `SkillsPanelUI` (sin ranking) | UI | Escena | `Control` | 3 |
| 26 | `CraftingUI` | UI | Escena | `Control` | 3 |
| 27 | `CraftingStation` | Nodo/Escena | Escena | `WorldObject` | 3 |
| 28 | `RoomBuilderUI` | UI | Escena | `Control` | 4 |
| 29 | `EquiparBehavior` | Resource | Recurso | `InteractionBehavior` | 4 |
| 30 | `MarketStall` | Nodo/Escena | Escena | `WorldObject` | 5 |
| 31 | `NPCTrader` | Nodo | Componente | `Node` | 5 |
| 32 | `MarketUI` | UI | Escena | `Control` | 5 |
| — | Ranking/leaderboard, resto de §3.4, capa de red | — | — | — | 6 (fuera del MVP) |

### Las once clases que esta tabla no detalla

La tabla de arriba cuenta **32 scripts**; [`CLASES.md`](CLASES.md) especifica **43 clases**. La diferencia no es un descuido: son clases que aparecieron al revisar el diseño en profundidad, y casi todas son recursos de datos diminutos —los diccionarios anidados de `items.json` (`receta`, `plantable`, `contenedor`, `efecto`) convertidos en `Resource` tipados, para que el inspector de Godot los valide en vez de dejarlos como `Dictionary` sueltos. Se listan acá para que nadie llegue a su fase y descubra que le falta una pieza; **su firma completa está en `CLASES.md`**, no en este documento.

| Clase | Capa | Extends | Fase | Por qué existe |
|---|---|---|---|---|
| `SaveGame` | Datos | `Resource` | 1 | El contenedor que `SaveManager` serializa; cada manager aporta su `to_dict()` (§3.8 de `SISTEMAS.md`) |
| **`ItemDatabase`** | Manager | `Node` | 2 | **D10** — índice `id → ItemDefinition` y `familia → [ItemDefinition]`. Sin él `RecipeManager` no puede resolver un insumo pedido por familia ("cualquier taza") |
| `InsumoReceta` | Datos | `Resource` | 2 | Un insumo de `RecipeDefinition`: `{id | familia, cantidad, consume}` |
| `PlantableData` | Datos | `Resource` | 2 | El campo `plantable` de una semilla: qué produce y en cuánto tiempo |
| `ContenedorData` | Datos | `Resource` | 2 | El campo `contenedor` de un utensilio: qué tipo de contenido admite |
| **`Modificador`** | Datos | `Resource` | 2 | **D5** — la forma única que comparten `efecto` (consumibles) y `bono` (equipables) |
| **`InventorySlot`** | Datos | `Resource` | 2 | **D1** — el slot de inventario en sus dos formas: apilado (`instancia == null`) o único (con `ItemInstance`) |
| **`GatherDrop`** | Datos | `Resource` | 2 | **D6** — una entrada de drop: `{item_id, cantidad_min, cantidad_max, probabilidad}` |
| **`GatherTable`** | Datos | `Resource` | 2 | **D6** — la tabla que consulta `GatherableNode`. Es donde vive el "en baja proporción" de la Semilla de manzana, que hoy no tiene dónde ir sin hardcodearlo |
| `AbrirCrafteoBehavior` | Datos | `InteractionBehavior` | 3 | El verbo que abre `CraftingUI` desde una `CraftingStation` |

La undécima no es una clase nueva sino un desdoblamiento: la fila 6 de la tabla de arriba agrupa `InteractionBehavior` **y** `SentarseBehavior`, que en `CLASES.md` se cuentan por separado.

### Scripts eliminados en la revisión "no reimplementar lo que Godot ya trae"

| Script propuesto originalmente | Por qué ya no existe |
|---|---|
| `InputController` | Godot ya tiene el **Input Map** (Project Settings → Input Map) y el singleton **`Input`**. Leer `Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")` dentro de `PlayerController` cubre todo lo que este script iba a hacer, y el Input Map ya soporta remapeo en runtime (`InputMap.action_erase_events()` / `action_add_event()`) si algún día hace falta configurar controles. Un script intermedio propio solo agregaba una capa sin aportar nada. |
| `CameraController` | Sigue eliminado tras el paso a 3D. La cámara es un `Node3D` pivote en el centro de la sala con una `Camera3D` ortográfica como hija, toda configurada desde el inspector (GDD §7). Rotar la sala en pasos de 90° es una interpolación sobre `pivote.rotation.y`, y encuadrar es mover el pivote — ninguna de las dos cosas justifica una clase. Si más adelante hace falta lógica real (transición de cámara entre salas, seguimiento con límites), se agrega ahí y recién entonces vuelve a ser un script. |

---

## Fase 1 — Sistema base (avatar en área común y sala privada)

### 1. `IsoGrid` — Nodo/Escena · Escena propia · `extends Node3D`
**Función:** es la autoridad sobre la grilla de una sala — qué celdas existen, cuáles se pueden caminar y qué `WorldObject` ocupa cada una. Coordina dos capas de escenario y lleva la ocupación de gameplay.

**Estructura de la escena** (§7 del GDD):
```
IsoGrid (Node3D)        ← el script
├── Suelo   (GridMap)
└── Paredes (GridMap)
```

**Por qué `Node3D` y no `extends GridMap`.** El script podría colgar del `GridMap` del suelo y heredar `map_to_local()` gratis, pero eso convertiría a las paredes en un apéndice de la capa de suelo cuando son dos representaciones de la misma sala. Además `IsoGrid` es dueño de *la ocupación y el área construible* (`SISTEMAS.md` §3.1), no de dibujar el piso: que el suelo sea un `GridMap` es un detalle de render. El costo de la indirección es un `suelo.` por cada conversión, cuatro líneas en total, y a cambio queda lugar para una tercera capa (techos, decoración fija) sin reorganizar nada.

**Godot nativo:** `GridMap` aporta el pintado con herramienta de editor, la conversión de coordenadas (`local_to_map()` / `map_to_local()`), el agrupado en lotes de las mallas y la colisión del escenario. La proyección isométrica **ya no es asunto de este nodo**: es el ángulo de la cámara (§7 del GDD), así que no hay matemática 2:1 ni `TileSet` que configurar, y el orden de dibujo lo resuelve el búfer de profundidad en vez de un y-sort. **Código propio:** la ocupación de gameplay — qué `WorldObject` está parado sobre cada celda, que el motor no modela.

**Convención de coordenadas:** la API pública habla en `Vector2i` (planta del piso) y convierte a `Vector3i` solo para hablar con los `GridMap`. Así `celda_origen` de **D3**, los `tamano_grilla` de `items.json` y el `AStarGrid2D` de `PlayerController` siguen valiendo tal como están escritos.

**Invariante:** los dos `GridMap` hijos van con transformación en cero, y el origen de `IsoGrid` es el origen de la sala. `map_to_local()` devuelve coordenadas en el espacio local del `GridMap`: si alguien mueve un hijo, las conversiones empiezan a mentir sin dar error.

**Interactúa con:** vive dentro de cada `RoomController`; `PlayerController` la consulta para moverse celda a celda; `WorldObject` se registra en ella al colocarse; en fase 4, `RoomBuilderUI` la usa para validar dónde se puede construir.

**Funciones clave:** `celda_a_mundo()` / `mundo_a_celda()` y `celda_bajo_puntero(camara, pos_pantalla)` para geometría; `celda_valida()`, `hay_pared()` y `esta_libre()` para transitabilidad; `celdas_de()`, `ocupar()`, `liberar_objeto()` y `objeto_en()` para ocupación; y **`ruta(origen, destino)`**, que mantiene el único `AStarGrid2D` de la sala. Firmas completas en [`CLASES.md`](CLASES.md) §3.1.

### 2. `PlayerController` — Nodo/Escena · Escena propia · `extends CharacterBody3D`
**Función:** movimiento del avatar sobre la grilla, estado de personaje (sentado, energía) y los métodos que invocan los `InteractionBehavior` (ej. `sentarse_en`, `reproducir_animacion`).
**Godot nativo:** `CharacterBody3D` con `move_and_slide()` para el desplazamiento; el singleton **`Input`** + Input Map para el control (sin script intermedio, ver tabla de eliminados); y **`AStarGrid2D`** para el pathfinding click-to-walk estilo Habbo. **`AStarGrid2D` sigue sirviendo aunque el mundo sea 3D**: opera sobre una grilla de enteros y no le importa la dimensión del render — se le pasan las celdas bloqueadas de `IsoGrid` y el resultado se mapea al plano XZ. **Código propio:** la lógica de estado del personaje y las respuestas a los comportamientos de interacción.
**Interactúa con:** se mueve dentro de la `IsoGrid` de la `RoomController` activa; `GameManager` lo referencia como "el jugador actual"; `SentarseBehavior` y futuros comportamientos llaman a sus métodos para producir el efecto visible.
**Funciones clave:** `_physics_process(delta: float) -> void`, `ir_a_celda(celda: Vector2i) -> void` (calcula ruta con `AStarGrid2D`), `sentarse_en(objeto: WorldObject) -> void`, `reproducir_animacion(nombre: String) -> void`.

### 3. `AvatarComposer` — Nodo · Componente · `extends Node3D`
**Función:** arma el avatar por partes intercambiables (cuerpo/torso/piernas/cabeza/tocado, §7) según apariencia y equipo actual. El requisito no cambió con el render 3D: la ropa de Costura es mercancía comerciable y tiene que verse puesta.
**Godot nativo:** un único `Skeleton3D` con un `BoneAttachment3D` por slot, y una malla intercambiable colgando de cada uno; el `AnimationPlayer` del rig mueve todo junto sin sistema de sincronización propio. Es menos trabajo que la versión 2D, donde había que componer cada capa en cada uno de los 4–8 ángulos. **Código propio:** solo decidir qué malla corresponde a cada slot según lo equipado.
**Interactúa con:** componente de `PlayerController`; desde fase 2 lee qué hay equipado en `InventoryManager` para reflejarlo visualmente.
**Pendiente de contenido, no de estructura:** el maniquí de KayKit son seis mallas separadas sobre un mismo esqueleto, así que intercambiar una parte es asignarle otro `Mesh` a su `MeshInstance3D`. Lo que falta son prendas que ponerle — hasta que existan, Costura no tiene efecto visible.
**Traducción de nombres de animación:** el script guarda un diccionario de nombre lógico (`&"caminar"`) a nombre del pack (`Rig_Medium_MovementBasic/Walking_A`). Es lo que evita que el resto del código conozca a KayKit: cambiar de pack de animaciones es reescribir ese diccionario y nada más.
**Funciones clave:** `actualizar_parte(slot: StringName, malla: Mesh) -> void`, `aplicar_equipo(item: ItemDefinition) -> void`.

### 4. `RoomController` — Nodo/Escena · Escena propia · `extends Node3D`
**Función:** representa una sala concreta (área común o sala privada): contiene una `IsoGrid`, los `WorldObject` colocados, el tipo de sala (vivienda/producción/tienda, GDD §6) y quién puede entrar.
**Godot nativo:** cada sala **es** una escena `.tscn`, así que cargarla es `load()` + `PackedScene.instantiate()` — no hace falta un formato propio de "definición de sala". El orden de dibujo lo resuelve el búfer de profundidad: **con el render 3D desapareció el y-sort** y con él la clase de bugs de objetos dibujados en el orden equivocado. **Código propio:** el estado de la sala y su relación con la ocupación de `IsoGrid`.
**Interactúa con:** instanciada y gestionada por `GameManager` al cambiar de escena; coloca y consulta `WorldObject` sobre su `IsoGrid`; en fase 4, `RoomBuilderUI` la usa para agregar/quitar objetos.
**Funciones clave:** `colocar_objeto(item: ItemDefinition, celda: Vector2i) -> WorldObject`, `obtener_objetos() -> Array[WorldObject]`.
**Nota de cámara:** el pivote con la `Camera3D` ortográfica (§7 del GDD) vive en la escena de la sala, centrado en ella. Sigue sin necesitar script: rotar la sala al estilo Habbo es una interpolación sobre `pivote.rotation.y`.

### 5. `WorldObject` — Nodo/Escena · Escena propia · `extends Area3D`
**Función:** cualquier objeto colocado en una sala. Referencia su `ItemDefinition`, guarda `estado_instancia` (dato propio de esa instancia) y expone `verbos_disponibles()` / `ejecutar()` del sistema de interacción (GDD §6.1).
**Godot nativo:** `Area3D` aporta la detección de click y de puntero encima mediante su señal `input_event` y una `CollisionShape3D` — no hay que hacer pruebas de picking a mano. Como la ocupación la lleva `IsoGrid`, la forma de colisión no necesita seguir la malla: un `BoxShape3D` del tamaño de la celda alcanza y es más barato. **Código propio:** el sistema de verbos de interacción y el estado por instancia, que son diseño propio del juego (§6.1).
**Interactúa con:** vive dentro de un `RoomController`; su lista `interacciones` son recursos `InteractionBehavior`; `ContextMenuUI` lo consulta para mostrar verbos; `PlayerController` es el actor que ejecuta comportamientos sobre él.
**Funciones clave:** `verbos_disponibles(actor: Node) -> Array[InteractionBehavior]`, `ejecutar(behavior: InteractionBehavior, actor: Node) -> bool` (**D8**), `_on_input_event(...)` (señal nativa de `Area3D`).

### 6. `InteractionBehavior` (clase base) + `SentarseBehavior` — Resource · Recurso, sin escena · `extends Resource` (`SentarseBehavior extends InteractionBehavior`)
**Función:** define qué puede hacer un jugador con un `WorldObject` (GDD §6.1), reutilizable y **sin estado propio** — el estado de una instancia concreta vive en `WorldObject.estado_instancia`, nunca en el `Resource`.
**Godot nativo:** `Resource` es exactamente el mecanismo del motor para esto: da serialización a `.tres`, edición desde el inspector, `@export` de parámetros y compartir la misma instancia entre muchos objetos. No hay nada que reimplementar acá — el patrón ya era el nativo.
**Interactúa con:** referenciado desde `ItemDefinition.interacciones`; lee/escribe `WorldObject.estado_instancia`; llama métodos de `PlayerController`.
**Funciones clave:** `puede_interactuar(actor: Node, objeto: WorldObject) -> bool`, `interactuar(actor: Node, objeto: WorldObject) -> void`.

### 7. `ContextMenuUI` — UI · Escena propia · `extends PopupMenu`
**Función:** menú contextual que aparece al interactuar con un `WorldObject`, listando sus verbos disponibles.
**Godot nativo:** **`PopupMenu`** ya resuelve el posicionamiento en pantalla, la lista de ítems con `add_item()`, la navegación por teclado, el cierre al hacer click afuera y la señal `id_pressed`. **Código propio:** solo poblarlo con los verbos que devuelve el objeto y mapear el id elegido al comportamiento correspondiente.
**Interactúa con:** llama `WorldObject.verbos_disponibles(actor)` para poblarse; al elegir una opción, invoca `WorldObject.ejecutar(behavior, actor)`.
**Funciones clave:** `mostrar_para(objeto: WorldObject, actor: Node) -> void`, `_on_id_pressed(id: int) -> void`.

### 8. `HUD` — UI · Escena propia · `extends CanvasLayer`
**Función:** capa fija de interfaz (energía, Ducados, notificaciones).
**Godot nativo:** `CanvasLayer` para que no se mueva con la cámara, `ProgressBar` para la barra de energía y `Label` para los Ducados — nada de dibujado propio.
**Interactúa con:** desde fase 2 lee energía de `PlayerController` y Ducados de `EconomyManager`.
**Funciones clave:** `actualizar_energia(valor: float) -> void`, `actualizar_ducados(valor: int) -> void`.

### 9. `GameManager` — Autoload · `extends Node`
**Función:** orquesta qué `RoomController` está activo (área común vs. sala privada) y mantiene la referencia global al jugador.
**Godot nativo:** el sistema de **autoloads** es el patrón singleton propio del motor, y `SceneTree.change_scene_to_packed()` / `change_scene_to_file()` ya maneja el cambio de escena con su liberación de memoria.
**Interactúa con:** instancia/destruye escenas de `RoomController`; es el punto central que el resto de los managers consultan para saber "quién es el jugador actual".
**Funciones clave:** `cambiar_sala(sala: PackedScene) -> void`, `jugador_actual() -> PlayerController`.

### 10. `SaveManager` (versión mínima) — Autoload · `extends Node`
**Función:** en fase 1 guarda/carga posición del jugador y última sala visitada; después se le suma el resto del estado.
**Godot nativo:** definir un `SaveGame extends Resource` con todo el estado como `@export`, y usar **`ResourceSaver.save()`** / **`ResourceLoader.load()`** contra `user://` — Godot serializa y deserializa todos los campos exportados solo, sin escribir código de serialización. (Alternativa si se prefiere un formato de texto inspeccionable y sin riesgo de ejecutar código al cargar: `FileAccess` + `JSON`.) **Código propio:** solo decidir qué entra en ese recurso.
**Interactúa con:** lee de `GameManager` qué guardar; desde fase 2 se le suman `InventoryManager`, `SkillManager`, `EconomyManager` y `TimeManager` como fuentes de datos a persistir.
**Funciones clave:** `guardar() -> void`, `cargar() -> void`.

---

## Fase 2 — Ciclo económico vertical (Agricultura → Cosecha → Cocina → Consumo, un NPC comprador)

### 11. `ItemDefinition` — Resource · Recurso, sin escena · `extends Resource`
**Función:** esquema de `docs/items/items.json` (GDD §8): id, categoría, stack, valor base, receta embebida, efecto, etc.
**Godot nativo:** `Resource` + `@export` da edición desde el inspector y archivos `.tres` versionables, que es justo el objetivo de §8 (agregar contenido sin tocar código).
**Interactúa con:** referenciado por `WorldObject`, `InventoryManager`, `RecipeManager`, `GatherableNode`; su campo `interacciones` apunta a recursos `InteractionBehavior`.
**Funciones clave:** `es_apilable() -> bool`, `tiene_interaccion(tipo: String) -> bool`.

### 12. `RecipeDefinition` — Resource · Recurso, sin escena · `extends Resource`
**Función:** esquema de una receta (insumos por `id` o por `familia`, habilidad, xp, nivel requerido, tiempo).
**Godot nativo:** `Resource` anidado dentro del `ItemDefinition` del resultado — Godot soporta recursos dentro de recursos de forma nativa, tal como ya modela `items.json`.
**Interactúa con:** `RecipeManager` la lee para validar y ejecutar un crafteo.
**Funciones clave:** `insumos_satisfechos(inventario: InventoryManager) -> bool`, `tiempo_total() -> float`.

### 13. `SkillDefinition` — Resource · Recurso, sin escena · `extends Resource`
**Función:** curva de xp y qué desbloquea cada nivel de una habilidad.
**Godot nativo:** el tipo **`Curve`** es un recurso de Godot que se edita **gráficamente** en el inspector — la curva de experiencia puede ser un `@export var curva_xp: Curve` en vez de una fórmula hardcodeada, lo que permite balancear la progresión arrastrando puntos en el editor sin recompilar nada.
**Interactúa con:** `SkillManager` la usa para calcular nivel a partir de xp acumulada y para resolver desbloqueos.
**Funciones clave:** `xp_para_nivel(nivel: int) -> int`, `nivel_para_xp(xp: int) -> int`.

### 14. `ItemInstance` — Resource · Recurso, sin escena · `extends Resource`
**Función:** una unidad concreta de un ítem con estado propio — ej. *esta* taza está servida con Café, *esta* semilla lleva 400 de los 900 segundos de crecimiento.
**Godot nativo:** al ser `Resource`, se persiste dentro del `SaveGame` sin código de serialización propio (ver `SaveManager`), y `duplicate()` ya existe en la clase base.
**Interactúa con:** vive dentro de los stacks de `InventoryManager` o en `WorldObject.estado_instancia`; `ContenedorBehavior` y `CropPlot` lo leen/modifican.
**Funciones clave:** `esta_vacio() -> bool` (`duplicate()` viene de `Resource`).

### 15. `SkillManager` — Autoload · `extends Node`
**Función:** trackea nivel/xp de cada habilidad, aplica ganancia de xp, resuelve desbloqueos.
**Godot nativo:** poco — es lógica propia del juego. Lo que sí aporta el motor son las **señales** (`signal nivel_subido(habilidad, nivel)`) para que la UI se actualice sin polling.
**Interactúa con:** `RecipeManager` y `GatherableNode` le reportan xp ganada; `SkillsPanelUI` lo lee; el nivel habilita/deshabilita recetas en `RecipeManager`.
**Funciones clave:** `agregar_xp(habilidad: String, cantidad: int) -> void`, `nivel_de(habilidad: String) -> int`.

### 16. `InventoryManager` — Autoload · `extends Node`
**Función:** contiene los `ItemInstance` del jugador; agrega/quita, valida stacks y peso.
**Godot nativo:** lógica propia del juego; el motor no tiene inventario. Usar señales (`signal inventario_cambiado`) para que `InventoryUI` reaccione sin consultar cada frame.
**Interactúa con:** `RecipeManager` consume/produce a través de él; `GatherableNode` agrega lo recolectado; `EconomyManager` lo consulta al vender; `MarketStall` también.
**Funciones clave:** `agregar_item(instancia: ItemInstance) -> bool`, `quitar_item(id: String, cantidad: int) -> bool`.

### 17. `RecipeManager` — Autoload · `extends Node`
**Función:** valida una `RecipeDefinition` contra `InventoryManager` (insumos por `familia`, flag `consume:false`), ejecuta el crafteo y otorga xp vía `SkillManager`.
**Godot nativo:** lógica propia; el motor no tiene sistema de crafteo. Para el tiempo de crafteo dentro de una sesión alcanza con `get_tree().create_timer()`, sin temporizador propio.
**Interactúa con:** invocado por `CraftingStation`/`CraftingUI`; lee `ItemDefinition.receta`; escribe en `InventoryManager`.
**Funciones clave:** `puede_craftear(receta: RecipeDefinition) -> bool`, `craftear(receta: RecipeDefinition) -> ItemInstance`.

### 18. `TimeManager` — Autoload · `extends Node`
**Función:** temporizadores que deben sobrevivir a cerrar el juego (crecimiento de cultivos, duración de buffs).
**Godot nativo:** el singleton **`Time`** (`Time.get_unix_time_from_system()`) da la marca de tiempo real. **Advertencia importante:** los nodos `Timer` y `get_tree().create_timer()` **no** sirven para esto — se detienen al cerrar el juego. Para cualquier cosa que crezca "mientras no estás", hay que guardar el timestamp de inicio y comparar contra `Time` al recargar; los `Timer` quedan solo para esperas dentro de una misma sesión.
**Interactúa con:** `CropPlot` lo consulta para saber si ya puede cosecharse; `ModifierStack` lo usa si se decide que los buffs expiren con el juego cerrado; `SaveManager` persiste sus timestamps.
**Funciones clave:** `registrar_temporizador(id: String, duracion_seg: float) -> void`, `tiempo_restante(id: String) -> float`.

### 19. `GatherableNode` — Nodo/Escena · Escena propia · `extends Area3D`
**Función:** nodo de recolección (árbol, mina, parcela) vinculado a una habilidad, con tiempo de acción, respawn y herramienta requerida.
**Godot nativo:** `Area3D` para detectar el click y la cercanía del jugador (señales `input_event` y `body_entered`), y un nodo `Timer` hijo para el respawn dentro de la sesión.
**Interactúa con:** vive dentro de una zona pública (`RoomController`) o de la sala de Producción del jugador; entrega `ItemInstance` a `InventoryManager` y xp a `SkillManager`; su velocidad sale de un único `ModifierStack.multiplicador_para()`, que ya combina el equipo equipado y los buffs activos (**D5**).
**Funciones clave:** `recolectar(actor: Node) -> void`, `_on_respawn_timeout() -> void`.

### 20. `CropPlot` — Nodo/Escena · Escena propia · `extends GatherableNode`
**Función:** variante para semillas plantables — al plantar arranca un temporizador y produce el resultado al cumplirse (campo `plantable` de `ItemDefinition`).
**Godot nativo:** hereda toda la detección de `Area3D` de `GatherableNode`. **Ojo:** a diferencia del respawn de su clase padre, el crecimiento **sí** debe ir por `TimeManager` (timestamps), no por un nodo `Timer` — un cultivo tiene que seguir creciendo con el juego cerrado.
**Interactúa con:** usa `TimeManager`; entrega el resultado a `InventoryManager` y xp a `SkillManager`.
**Funciones clave:** `plantar(semilla: ItemDefinition) -> void`, `esta_lista_para_cosechar() -> bool`.

### 21. `ContenedorBehavior` — Resource · Recurso, sin escena · `extends InteractionBehavior`
**Función:** generaliza tazas y platos — declara tipo (líquido/sólido) y capacidad, permite servir/vaciar.
**Godot nativo:** `Resource` con `@export` para tipo y capacidad, de modo que las variantes (taza vs. plato) son archivos `.tres` distintos del mismo script, sin código por variante.
**Interactúa con:** asignado en `ItemDefinition.interacciones` de tazas y platos; lee/escribe el estado de un `ItemInstance`; `RecipeManager` lo consulta al craftear consumibles con `consume:false`.
**Funciones clave:** `servir(objeto: WorldObject, contenido_id: String) -> void`, `vaciar(objeto: WorldObject) -> void`.

### 22. `ModifierStack` — Nodo · Componente · `extends Node`
> Antes se llamaba `BuffController`. Renombrado al cerrar el lado de datos de **D5**: no solo trackea buffs temporales, también absorbe los bonos del equipo equipado, para que exista **un único punto de consulta** de "cuánto más rápido va esta habilidad ahora".
**Función:** acumula todos los `Modificador` activos sobre el jugador —los temporales de un consumible (ej. +10% velocidad de Manufactura por Café) y los permanentes de la herramienta equipada (ej. +15% de Agricultura por la Pala)— y responde con un multiplicador único por habilidad.
**Godot nativo:** para buffs que solo importan durante la sesión, `get_tree().create_timer(duracion)` con su señal `timeout` evita escribir cualquier contador propio; si se decide que los buffs sigan corriendo con el juego cerrado, van por `TimeManager` igual que los cultivos (`SISTEMAS.md` §3.5 recomienda lo primero: buffs por sesión, cultivos por timestamp).
**Interactúa con:** se activa al consumir un `ItemDefinition` con campo `efecto` y al equipar uno con campo `bono` — ambos comparten esquema desde D5; `GatherableNode`/`RecipeManager` le piden el multiplicador en vez de consultar dos sistemas y combinarlos a mano.
**Funciones clave:** `aplicar_modificador(mod: Modificador) -> void`, `multiplicador_para(habilidad: StringName) -> float`.

### 23. `EconomyManager` (versión básica) — Autoload · `extends Node`
**Función:** Ducados del jugador y compra de emergencia de materia prima a precio piso por un NPC (GDD §5).
**Godot nativo:** lógica propia; señales para avisar cambios de saldo al `HUD`. Sigue desacoplado del transporte (GDD §8) para el multijugador futuro.
**Interactúa con:** descuenta/agrega ítems vía `InventoryManager`; en fase 5 se extiende con `MarketStall`/`NPCTrader`.
**Funciones clave:** `vender_a_npc(item_id: String, cantidad: int) -> int`, `ducados_actuales() -> int`.

---

## Fase 3 — Inventario + UI de crafteo genérica

### 24. `InventoryUI` — UI · Escena propia · `extends Control`
**Función:** muestra el contenido de `InventoryManager`, permite arrastrar/soltar y equipar.
**Godot nativo:** `GridContainer` para la grilla de slots, y sobre todo la **API nativa de drag & drop de `Control`** (`_get_drag_data()`, `_can_drop_data()`, `_drop_data()`) — no hay que implementar el arrastre a mano. `ItemList` es una alternativa si alcanza con una lista simple en vez de una grilla de slots.
**Interactúa con:** lee/escribe `InventoryManager` directamente.
**Funciones clave:** `refrescar() -> void`, `_get_drag_data(pos: Vector2) -> Variant`, `_drop_data(pos: Vector2, data: Variant) -> void`.

### 25. `SkillsPanelUI` (sin ranking) — UI · Escena propia · `extends Control`
**Función:** muestra nivel y xp de cada habilidad. El ranking queda fuera del MVP (GDD §3.4) porque necesita otros jugadores.
**Godot nativo:** `VBoxContainer` + un `ProgressBar` por habilidad; la señal `nivel_subido` de `SkillManager` dispara el refresco.
**Interactúa con:** lee `SkillManager`.
**Funciones clave:** `refrescar() -> void`.

### 26. `CraftingUI` — UI · Escena propia · `extends Control`
**Función:** interfaz de crafteo genérica: lista de recetas disponibles según `RecipeDefinition` y nivel del jugador.
**Godot nativo:** `ItemList` (o `Tree` si se quieren columnas de insumos) + `Button`; la barra de progreso del crafteo es un `ProgressBar` alimentado por el timer de `RecipeManager`.
**Interactúa con:** invoca `RecipeManager`; lee `InventoryManager` para mostrar si hay insumos.
**Funciones clave:** `mostrar_recetas(habilidad: String) -> void`, `_on_craftear_pressed(receta: RecipeDefinition) -> void`.

### 27. `CraftingStation` — Nodo/Escena · Escena propia · `extends WorldObject`
**Función:** objeto del mundo (mesada de cocina, banco de carpintería) que abre `CraftingUI` filtrada por su habilidad.
**Godot nativo:** hereda de `WorldObject`, o sea del `Area3D` con detección de click ya resuelta; el verbo que abre la UI es un `InteractionBehavior` más, sin mecanismo nuevo.
**Interactúa con:** su lista `interacciones` incluye un comportamiento que abre `CraftingUI`; conecta con `RecipeManager` a través de esa UI.
**Funciones clave:** `abrir_ui(actor: Node) -> void`.

---

## Fase 4 — Parcela y construcción de sala

### 28. `RoomBuilderUI` — UI · Escena propia · `extends Control`
**Función:** modo construcción: colocar, rotar y eliminar `WorldObject` sobre la `IsoGrid`.
**Godot nativo:** el "snap" a celda sale de `IsoGrid.mundo_a_celda(get_global_mouse_position())`, sin matemática propia; el fantasma de previsualización es el mismo `WorldObject` con `modulate.a` bajado; arrastrar ítems desde el inventario reusa la API de drag & drop de `Control`. **Código propio:** la validación de colocación contra la ocupación de `IsoGrid`.
**Interactúa con:** usa `IsoGrid` para validar (`tamano_grilla`/`rotable` de `ItemDefinition`); instancia `WorldObject` a partir de ítems de `InventoryManager`; `RoomController` persiste el resultado.
**Funciones clave:** `entrar_modo_construccion() -> void`, `colocar(item: ItemDefinition, celda: Vector2i) -> void`.

### 29. `EquiparBehavior` — Resource · Recurso, sin escena · `extends InteractionBehavior`
**Función:** "equipar" herramientas (Pala de hierro, Pico de minería) — mueve el ítem a un slot del jugador y aplica su bono.
**Godot nativo:** `Resource` con `@export`, igual que el resto de comportamientos; el reflejo visual del equipo lo resuelve `AvatarComposer`.
**Interactúa con:** modifica un slot en `PlayerController`/`InventoryManager`; su bono lo lee `GatherableNode` al calcular velocidad.
**Funciones clave:** `interactuar(actor: Node, objeto: WorldObject) -> void`, `quitar_equipo(actor: Node, slot: String) -> void`.

---

## Fase 5 — Mercado simulado (varios NPCs)

### 30. `MarketStall` — Nodo/Escena · Escena propia · `extends WorldObject`
**Función:** puesto de venta en una sala tipo Tienda; lista los precios que fija el dueño.
**Godot nativo:** hereda la detección de interacción de `WorldObject`; la UI de compra es un `PopupPanel` o una escena de `Control`, no una ventana propia.
**Interactúa con:** lee el `InventoryManager` del dueño; una compra mueve Ducados e ítems vía `EconomyManager`.
**Funciones clave:** `listar_precio(item_id: String, precio: int) -> void`, `comprar(actor: Node, item_id: String) -> void`.

### 31. `NPCTrader` — Nodo · Componente · `extends Node`
**Función:** IA simple de compra/venta según oferta y demanda, para probar el balance antes de tener red real.
**Godot nativo:** un nodo `Timer` hijo para el "tick" periódico de mercado en vez de contar frames en `_process`.
**Interactúa con:** opera contra `EconomyManager` y `MarketStall`/tablón central.
**Funciones clave:** `evaluar_precio(item_id: String) -> int`, `_on_tick_timeout() -> void`.

### 32. `MarketUI` — UI · Escena propia · `extends Control`
**Función:** tablón centralizado para descubrir precios sin visitar sala por sala.
**Godot nativo:** el nodo **`Tree`** está hecho para datos tabulares con columnas ordenables (ítem / precio / vendedor) — es la herramienta correcta acá, en vez de armar filas a mano con `HBoxContainer`.
**Interactúa con:** lee ofertas agregadas de `EconomyManager`.
**Funciones clave:** `refrescar_ofertas() -> void`.

---

## Fase 6 — Networking (fuera del MVP)

No se detalla a nivel de script todavía — es la fase donde entra un servidor autoritativo real (GDD §8, §9). Lo que sí queda anotado: `EconomyManager`, `InventoryManager`, `SkillManager` y el resto de los managers de fase 2 están **diseñados desde ya desacoplados del transporte**, específicamente para que esta fase no obligue a rediseñarlos. Sobre esta base se construye:

- **Ranking/leaderboard** y el resto de las ideas de competencia de GDD §3.4 (necesitan otros jugadores reales).
- Validación server-side de `InteractionBehavior.interactuar()` y de `RecipeManager`/`EconomyManager`, reusando exactamente la misma lógica que corre en local durante el MVP.
- **Godot nativo a evaluar cuando llegue el momento:** el motor trae `ENetMultiplayerPeer`, `MultiplayerSynchronizer` y `MultiplayerSpawner`, que cubren buena parte de la sincronización de estado sin escribir un protocolo propio.
