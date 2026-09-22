# MumiolaCity — Arquitectura de scripts

> Complementa [`GDD.md`](GDD.md) (especialmente §6.1 Interactividad de objetos y §8 Arquitectura técnica) y el roadmap de fases de `GDD.md` §9. Este documento no es código: es el mapa de qué scripts van a existir, qué hace cada uno, si es una escena propia o un script suelto, qué clase de Godot hereda, un par de funciones clave que debería tener, y de qué otros scripts depende — ordenado por la secuencia en la que conviene implementarlos. Actualizar junto con `GDD.md` si cambia el roadmap o el sistema de interacción.
>
> **Versión navegable (artefacto):** https://claude.ai/code/artifact/5f914cd8-0d3b-437a-981a-0f18a4bb0a82 — mismo contenido que este archivo, con navegación por fase y enlaces cruzados entre scripts. Privado; compartir desde el menú de la página si hace falta. Si este documento cambia, hay que republicar el artefacto para que no quede desactualizado.
>
> **Revisado el 2026-09-15:** el proyecto pasó de sprites 2.5D pre-renderizados a **mundo 3D en tiempo real con cámara ortográfica isométrica** (GDD §7). Solo cambió la capa Mundo — nueve clases pasan a bases 3D y `IsoGrid` se reorganiza sobre dos `GridMap`. Los ocho managers, los once recursos de datos y toda la economía quedaron intactos, que es exactamente lo que compraba la regla de dirección de `SISTEMAS.md` §1.
>
> **Sistemas y decisiones abiertas:** ver [`SISTEMAS.md`](SISTEMAS.md) — cómo se comunican estos scripts entre sí, dónde vive cada dato y las once decisiones (D1–D11) que hay que cerrar antes de escribir el código de cada fase.
>
> **Firma de cada clase:** ver [`CLASES.md`](CLASES.md) — campos `@export`, señales, métodos e invariantes de las 55 clases. Este documento detalla **39**: las otras nueve son recursos de datos que aparecieron al revisar el diseño y se listan, con su fase y su motivo, en la tabla "Las clases que esta tabla no detalla" de más abajo.
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
| 0 | `Errores` | Definición | Global (`class_name`) | `RefCounted` | 1 (transversal) |
| 0b | `CatalogoPiezas` | Definición | Global (`class_name`) | `RefCounted` | 1 (transversal) |
| 0c | `OperacionSala` | Definición | Global (`class_name`) | `Resource` | 3 (costura de red, D23) |
| 1 | `IsoGrid` | Nodo/Escena | Escena | `Node3D` | 1 |
| 2 | `PersonajeControlador` | Nodo/Escena | Escena | `CharacterBody3D` | 1 |
| 3 | `AvatarComposer` | Nodo | Componente | `Node3D` | 1 |
| 3b | `IndicadorCelda` | Nodo | Componente | `MeshInstance3D` | 1 como ayuda, 3 como vista previa |
| 4 | `RoomController` | Nodo/Escena | Escena | `Node3D` | 1 |
| 5 | `WorldObject` | Nodo/Escena | Escena | `Area3D` | 1 |
| 6 | `InteractionBehavior` (+ `SentarseBehavior`) | Resource | Recurso | `Resource` | 1 |
| 6b | `MirarBehavior` | Resource | Recurso | `InteractionBehavior` | 3 (verbo universal) |
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
| 18 | `TimeManager` | Autoload | Autoload | `Node` | 5 |
| 19 | `GatherableNode` | Nodo/Escena | Escena | `Area3D` | 5 |
| 20 | `CropPlot` | Nodo/Escena | Escena | `GatherableNode` | 5 |
| 21 | `ContenedorBehavior` | Resource | Recurso | `InteractionBehavior` | 4 |
| 22 | `ModifierStack` | Nodo | Componente | `Node` | — (sin buffs ni energia en el MVP) |
| 23 | `EconomyManager` (básico) | Autoload | Autoload | `Node` | 5 |
| 24 | `InventoryUI` | UI | Escena | `Control` | 4 |
| 25 | `SkillsPanelUI` (sin ranking) | UI | Escena | `Control` | 4 |
| 26 | `CraftingUI` | UI | Escena | `Control` | 4 |
| 27 | `CraftingStation` | Nodo/Escena | Escena | `WorldObject` | 4 |
| 28 | `RoomBuilderUI` | UI | Escena | `Control` | 3 (paleta del editor) |
| 28b | `EditorSala` | Nodo | Componente | `Node3D` | 3 |
| 29 | `EquiparBehavior` | Resource | Recurso | `InteractionBehavior` | 4 |
| 30 | `MarketStall` | Nodo/Escena | Escena | `WorldObject` | 5 |
| 31 | `NPCTrader` | Nodo | Componente | `Node` | 5 |
| 32 | `MarketUI` | UI | Escena | `Control` | 5 |
| 33 | `GenerarIconos` | Herramienta | `EditorScript` | `EditorScript` | 3 |
| 34 | `PoseBehavior` | Resource | Recurso | `InteractionBehavior` | 4 |
| 35 | `LevantarBehavior` | Resource | Recurso | `InteractionBehavior` | 4 |
| 36 | `SuperficieBehavior` | Resource | Recurso | `InteractionBehavior` | 4 |
| 37 | `AlternarBehavior` | Resource | Recurso | `InteractionBehavior` | 4 |
| 38 | `AbrirCrafteoBehavior` | Resource | Recurso | `InteractionBehavior` | 4 |
| — | Ranking/leaderboard, resto de §3.4, capa de red | — | — | — | 6 (fuera del MVP) |

### Las clases que esta tabla no detalla

La tabla de arriba cuenta **39 scripts**; [`CLASES.md`](CLASES.md) especifica **55 clases**. La diferencia no es un descuido: son clases que aparecieron al revisar el diseño en profundidad, y casi todas son recursos de datos diminutos —los diccionarios anidados de `items.json` (`receta`, `plantable`, `contenedor`, `efecto`) convertidos en `Resource` tipados, para que el inspector de Godot los valide en vez de dejarlos como `Dictionary` sueltos. Se listan acá para que nadie llegue a su fase y descubra que le falta una pieza; **su firma completa está en `CLASES.md`**, no en este documento.

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
| `InputController` | Godot ya tiene el **Input Map** (Project Settings → Input Map) y el singleton **`Input`**. Leer `Input.get_vector("mover_izq", "mover_der", "mover_arriba", "mover_abajo")` dentro de `PersonajeControlador` cubre todo lo que este script iba a hacer, y el Input Map ya soporta remapeo en runtime (`InputMap.action_erase_events()` / `action_add_event()`) si algún día hace falta configurar controles. Un script intermedio propio solo agregaba una capa sin aportar nada. |
| `CameraController` | Sigue eliminado tras el paso a 3D. La cámara es un `Node3D` pivote en el centro de la sala con una `Camera3D` ortográfica como hija, toda configurada desde el inspector (GDD §7). Rotar la sala en pasos de 90° es una interpolación sobre `pivote.rotation.y`, y encuadrar es mover el pivote — ninguna de las dos cosas justifica una clase. Si más adelante hace falta lógica real (transición de cámara entre salas, seguimiento con límites), se agrega ahí y recién entonces vuelve a ser un script. |

---

## Fase 1 — Sistema base (avatar en área común y sala privada)

### 0. `Errores` — Definición · Global vía `class_name` · `extends RefCounted`
**Función:** el enum único de códigos de rechazo del juego más su mensaje para el jugador. Toda operación que pueda ser rechazada —colocar, comprar, craftear, entrar a una sala— devuelve un `Errores.Codigo` en lugar de un `bool`.
**Godot nativo:** `enum` con valores explícitos y `static func`, que en GDScript 2 son accesibles desde el `class_name` sin instanciar ni registrar autoload. **Código propio:** la tabla de códigos y sus textos, que son contenido del juego.
**Interactúa con:** todo lo que pueda fallar de cara al jugador. En fase 1, `RoomController.colocar_objeto()` y `retirar_objeto()`; en fase 4, la validación de **D12** y **D14**; en fase 5, el mercado. `ContextMenuUI` y `HUD` toman de acá el texto que muestran.
**Funciones clave:** `Errores.mensaje(codigo) -> String` y `Errores.ok(codigo) -> bool`. Enum completo en [`CLASES.md`](CLASES.md) §0.1.

### 0b. `CatalogoPiezas` — Definición · Global vía `class_name` · `extends RefCounted`
**Función:** el contrato entre las salas pintadas y las `MeshLibrary` del escenario (**D18**). Declara qué piezas tiene que traer cada capa y con qué prefijo se llaman, y traduce entre nombre e id.
**Godot nativo:** `MeshLibrary.find_item_by_name()` y `get_item_list()`, que son lo que hace del nombre una clave de primera clase. **Código propio:** la lista de piezas esperadas por capa y los prefijos, que son contenido del juego.
**Interactúa con:** `IsoGrid._validar_piezas()` lo comprueba al arrancar; `RoomController.to_dict()` y `SaveManager` lo van a usar para serializar por nombre en vez de por id.
**Funciones clave:** `id_de(biblioteca, nombre)`, `nombre_de(biblioteca, id)`, `corresponde_a(nombre, capa)` y `verificar(biblioteca, capa) -> Array[String]`.

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

**Convención de coordenadas:** la API pública habla en `Vector2i` (planta del piso) y convierte a `Vector3i` solo para hablar con los `GridMap`. Así `celda_origen` de **D3**, los `tamano_grilla` de `items.json` y el `AStarGrid2D` de `PersonajeControlador` siguen valiendo tal como están escritos.

**Invariante:** los dos `GridMap` hijos van con transformación en cero, y el origen de `IsoGrid` es el origen de la sala. `map_to_local()` devuelve coordenadas en el espacio local del `GridMap`: si alguien mueve un hijo, las conversiones empiezan a mentir sin dar error.

**Interactúa con:** vive dentro de cada `RoomController`; `PersonajeControlador` la consulta para moverse celda a celda; `WorldObject` se registra en ella al colocarse; en fase 4, `RoomBuilderUI` la usa para validar dónde se puede construir.

**Funciones clave:** `celda_a_mundo()` / `mundo_a_celda()` y `celda_bajo_puntero(camara, pos_pantalla)` para geometría; `celda_valida()`, `hay_pared()` y `esta_libre()` para transitabilidad; `celdas_de()`, `ocupar()`, `liberar_objeto()` y `objeto_en()` para ocupación; y **`ruta(origen, destino)`**, que mantiene el único `AStarGrid2D` de la sala. Firmas completas en [`CLASES.md`](CLASES.md) §3.1.

### 2. `PersonajeControlador` — Nodo/Escena · Escena propia · `extends CharacterBody3D`
**Función:** movimiento del avatar sobre la grilla, estado de personaje (sentado, energía) y los métodos que invocan los `InteractionBehavior` (ej. `sentarse_en`, `reproducir_animacion`).
**Godot nativo:** `CharacterBody3D` con `move_and_slide()` para el desplazamiento; el singleton **`Input`** + Input Map para el control (sin script intermedio, ver tabla de eliminados); y **`AStarGrid2D`** para el pathfinding click-to-walk estilo Habbo. **`AStarGrid2D` sigue sirviendo aunque el mundo sea 3D**: opera sobre una grilla de enteros y no le importa la dimensión del render — se le pasan las celdas bloqueadas de `IsoGrid` y el resultado se mapea al plano XZ. **Código propio:** la lógica de estado del personaje y las respuestas a los comportamientos de interacción.
**Interactúa con:** se mueve dentro de la `IsoGrid` de la `RoomController` activa; `GameManager` lo referencia como "el jugador actual"; `SentarseBehavior` y futuros comportamientos llaman a sus métodos para producir el efecto visible.
**Funciones clave:** `_physics_process(delta: float) -> void`, `ir_a_celda(celda: Vector2i) -> void` (calcula ruta con `AStarGrid2D`), `sentarse_en(objeto: WorldObject) -> void`, `reproducir_animacion(nombre: String) -> void`.

### 3. `AvatarComposer` — Nodo · Componente · `extends Node3D`
**Función:** arma el avatar por partes intercambiables (cuerpo/torso/piernas/cabeza/tocado, §7) según apariencia y equipo actual. El requisito no cambió con el render 3D: la ropa de Costura es mercancía comerciable y tiene que verse puesta.
**Godot nativo:** un único `Skeleton3D` con un `BoneAttachment3D` por slot, y una malla intercambiable colgando de cada uno; el `AnimationPlayer` del rig mueve todo junto sin sistema de sincronización propio. Es menos trabajo que la versión 2D, donde había que componer cada capa en cada uno de los 4–8 ángulos. **Código propio:** solo decidir qué malla corresponde a cada slot según lo equipado.
**Interactúa con:** componente de `PersonajeControlador`; desde fase 2 lee qué hay equipado en `InventoryManager` para reflejarlo visualmente.
**Pendiente de contenido, no de estructura:** el maniquí de KayKit son seis mallas separadas sobre un mismo esqueleto, así que intercambiar una parte es asignarle otro `Mesh` a su `MeshInstance3D`. Lo que falta son prendas que ponerle — hasta que existan, Costura no tiene efecto visible.
**Traducción de nombres de animación:** el script guarda un diccionario de nombre lógico (`&"caminar"`) a nombre del pack (`Rig_Medium_MovementBasic/Walking_A`). Es lo que evita que el resto del código conozca a KayKit: cambiar de pack de animaciones es reescribir ese diccionario y nada más.
**Funciones clave:** `actualizar_parte(slot: StringName, malla: Mesh) -> void`, `aplicar_equipo(item: ItemDefinition) -> void`.

### 4. `RoomController` — Nodo/Escena · Escena propia · `extends Node3D`
**Función:** una sala del mundo — su grilla, sus objetos, su encuadre y quién la posee. Enciende y apaga, y es lo que permite que existan dos salas y se pueda ir de una a la otra.
**Godot nativo:** `process_mode` y `visible` para apagar la sala entera de una vez; `Camera3D.current` para el turno de cámara, que el motor ya arbitra por viewport; un `Node3D` pivote para el encuadre isométrico y su rotación en cuartos de vuelta. **Código propio:** la noción de sala —tipo, dueño, celda de entrada— y las transacciones de colocar y retirar, que el motor no modela.
**Interactúa con:** contiene un `IsoGrid` y un contenedor `Objetos`; `Mundo` —y en el paso 9 `GameManager`— la enciende y apaga; `PersonajeControlador.entrar_en(sala)` le pide la grilla, la cámara y la posición de entrada. **No conoce al personaje**: las dependencias apuntan hacia abajo.
**Funciones clave:** `activar()` / `desactivar()` / `esta_activa()`, `posicion_de_entrada()`, `rotar(pasos)` y `objetos()`. `colocar_objeto()` y `retirar_objeto()` llegan con el paso 5, porque reciben y devuelven `ItemInstance`. Firmas completas en [`CLASES.md`](CLASES.md) §3.4.

### 5. `WorldObject` — Nodo/Escena · Escena propia · `extends Area3D`
**Función:** cualquier objeto colocado en una sala. Referencia su `ItemDefinition`, guarda `estado_instancia` (dato propio de esa instancia) y expone `verbos_disponibles()` / `ejecutar()` del sistema de interacción (GDD §6.1).
**Godot nativo:** `Area3D` aporta la detección de click y de puntero encima mediante su señal `input_event` y una `CollisionShape3D` — no hay que hacer pruebas de picking a mano. Como la ocupación la lleva `IsoGrid`, la forma de colisión no necesita seguir la malla: un `BoxShape3D` del tamaño de la celda alcanza y es más barato. **Código propio:** el sistema de verbos de interacción y el estado por instancia, que son diseño propio del juego (§6.1).
**Interactúa con:** vive dentro de un `RoomController`; su lista `interacciones` son recursos `InteractionBehavior`; `ContextMenuUI` lo consulta para mostrar verbos; `PersonajeControlador` es el actor que ejecuta comportamientos sobre él.
**Funciones clave:** `verbos_disponibles(actor: Node) -> Array[InteractionBehavior]`, `ejecutar(behavior: InteractionBehavior, actor: Node) -> bool` (**D8**), `_on_input_event(...)` (señal nativa de `Area3D`).

### 6. `InteractionBehavior` (clase base) + `SentarseBehavior` — Resource · Recurso, sin escena · `extends Resource` (`SentarseBehavior extends InteractionBehavior`)
**Función:** define qué puede hacer un jugador con un `WorldObject` (GDD §6.1), reutilizable y **sin estado propio** — el estado de una instancia concreta vive en `WorldObject.estado_instancia`, nunca en el `Resource`.
**Godot nativo:** `Resource` es exactamente el mecanismo del motor para esto: da serialización a `.tres`, edición desde el inspector, `@export` de parámetros y compartir la misma instancia entre muchos objetos. No hay nada que reimplementar acá — el patrón ya era el nativo.
**Interactúa con:** referenciado desde `ItemDefinition.interacciones`; lee/escribe `WorldObject.estado_instancia`; llama métodos de `PersonajeControlador`.
**Funciones clave:** `puede_interactuar(actor: Node, objeto: WorldObject) -> bool`, `interactuar(actor: Node, objeto: WorldObject) -> void`.

### 7. `ContextMenuUI` — UI · Escena propia · `extends PopupMenu`
**Función:** menú contextual que aparece al interactuar con un `WorldObject`, listando sus verbos disponibles.
**Godot nativo:** **`PopupMenu`** ya resuelve el posicionamiento en pantalla, la lista de ítems con `add_item()`, la navegación por teclado, el cierre al hacer click afuera y la señal `id_pressed`. **Código propio:** solo poblarlo con los verbos que devuelve el objeto y mapear el id elegido al comportamiento correspondiente.
**Interactúa con:** llama `WorldObject.verbos_disponibles(actor)` para poblarse; al elegir una opción, invoca `WorldObject.ejecutar(behavior, actor)`.
**Funciones clave:** `mostrar_para(objeto: WorldObject, actor: Node) -> bool` — devuelve `false` y no abre nada si el objeto no ofrece verbos, porque un menú vacío se lee como un bug — y la señal `verbo_elegido`, que el menú emite en vez de ejecutar: quien escucha decide, y hoy es el personaje, que camina hasta el mueble antes de actuar.
**Requisito fácil de olvidar:** `Viewport.physics_object_picking` viene **apagado** en 3D. Sin activarlo, ningún `Area3D` recibe clics y no hay error que lo delate — los muebles simplemente no responden. `Mundo` lo enciende en `_ready()`.

### 8. `HUD` — UI · Escena propia · `extends CanvasLayer`
**Función:** capa fija de interfaz (energía, Ducados, notificaciones).
**Godot nativo:** `CanvasLayer` para que no se mueva con la cámara, `ProgressBar` para la barra de energía y `Label` para los Ducados — nada de dibujado propio.
**Interactúa con:** desde fase 2 lee energía de `PersonajeControlador` y Ducados de `EconomyManager`.
**Funciones clave:** `mostrar_sala(sala)`, `avisar(texto)`, `avisar_error(codigo)` — que es donde `Errores.mensaje()` deja de ser texto que nadie lee — y `mostrar_ayuda(texto)`. Más `actualizar_energia(valor)` y `actualizar_ducados(valor)`, cuyos widgets **arrancan ocultos** y aparecen al primer valor: en fase 1 esos datos todavía no existen, y una barra vacía con un cero no informa nada.
**El texto de la ayuda lo pasa quien llama**, no vive en el HUD: hoy son los atajos provisionales de `Mundo`, y cuando dejen de existir el `Label` se queda sin que haya que tocar esta clase.

### 9. `GameManager` — Autoload · `extends Node`
**Función:** orquesta qué `RoomController` está activo (área común vs. sala privada) y mantiene la referencia global al jugador.
**Godot nativo:** el sistema de **autoloads** es el patrón singleton propio del motor, y `SceneTree.change_scene_to_packed()` / `change_scene_to_file()` ya maneja el cambio de escena con su liberación de memoria.
**Interactúa con:** instancia/destruye escenas de `RoomController`; es el punto central que el resto de los managers consultan para saber "quién es el jugador actual".
**Funciones clave:** `cambiar_sala(sala: PackedScene) -> void`, `jugador_actual() -> PersonajeControlador`.

### 10. `SaveManager` (versión mínima) — Autoload · `extends Node`
**Función:** en fase 1 guarda/carga posición del jugador y última sala visitada; después se le suma el resto del estado.
**Godot nativo:** definir un `SaveGame extends Resource` con todo el estado como `@export`, y usar **`ResourceSaver.save()`** / **`ResourceLoader.load()`** contra `user://` — Godot serializa y deserializa todos los campos exportados solo, sin escribir código de serialización. (Alternativa si se prefiere un formato de texto inspeccionable y sin riesgo de ejecutar código al cargar: `FileAccess` + `JSON`.) **Código propio:** solo decidir qué entra en ese recurso.
**Interactúa con:** lee de `GameManager` qué guardar; desde fase 2 se le suman `InventoryManager`, `SkillManager`, `EconomyManager` y `TimeManager` como fuentes de datos a persistir.
**Funciones clave:** `guardar() -> void`, `cargar() -> void`.

---

## Fase 2 — Los datos y los managers de la economía

> **La fase 2 se partió en dos y sólo la primera mitad se hizo.** La **2a** —catálogo, inventario, habilidades y crafteo, sin interfaz— está terminada y verificada: son las entradas 11 a 17 de acá abajo. El resto (`TimeManager`, `GatherableNode`, `CropPlot`, `EconomyManager`) se movió a la **fase 5** con el replan, porque la economía dejó de ser el MVP. Sus fichas están en esa sección.

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

## Fase 3 — El editor de sala

El MVP. Colocar y quitar muebles con vista previa, pintar suelo y paredes, deshacer, guardar y cargar. **Listo cuando** armás una sala entera desde cero, deshacés lo que no te gustó, la guardás, cerrás el juego, la abrís y está igual — y al volver a modo juego el personaje camina por el suelo nuevo y rodea las paredes nuevas.

### 0c. `OperacionSala` — Definición · Global (`class_name`) · `extends Resource` · **hecho**
**Función:** un cambio a una sala como dato en vez de como llamada: colocar, retirar, pintar, borrar. Es la costura por donde entra la red (**D23**).
**Godot nativo:** `Resource` con `@export`, igual que el resto de los datos del proyecto; `to_dict()`/`desde_dict()` siguen la forma de `SaveGame`.
**Interactúa con:** la construye `EditorSala` y la consume `RoomController.aplicar()`. Nadie más la toca.
**Funciones clave:** `colocar()`, `retirar()`, `pintar()`, `borrar()` como constructores estáticos; `to_dict()`, `desde_dict()`.

### 3b. `IndicadorCelda` (ampliado) — Nodo · Componente · `extends MeshInstance3D` · **hecho**
**Función:** la vista previa de colocación: la huella completa en recuadros coloreados celda por celda, más un fantasma translúcido de la malla.
**Godot nativo:** `PlaneMesh` reciclados como hijos; `GeometryInstance3D.transparency` para el fantasma —`modulate` es de `CanvasItem` y no hace nada en 3D—; `instantiate()` sin agregar al árbol para sacar el hijo `Visual` sin despertar al `WorldObject`.
**Interactúa con:** `IsoGrid.celdas_de()`, `centro_de()` y `motivo_bloqueo()`; recibe qué mostrar de `RoomBuilderUI` vía `EditorSala`.
**Funciones clave:** `elegir(definicion, rotacion)`, `mostrar(definicion, celda, rotacion)`, `ocultar()`, `motivo()`.

### 33. `GenerarIconos` — Herramienta · `EditorScript`
**Función:** ninguno de los 52 ítems tiene icono, y una paleta de 45 filas de texto es inusable. Renderiza cada `escena_mundo` y guarda un PNG en `arte/iconos/<id>.png`.
**Godot nativo:** `SubViewport` con `render_target_update_mode = ONCE` y una `Camera3D` ortográfica; `get_texture().get_image().save_png()`. Corre una vez desde el editor, no en el juego.
**Interactúa con:** lo lee `ImportarItems.gd`, que asigna `ItemDefinition.icono` si el archivo existe.
**Funciones clave:** `_run() -> void`, `_render_de(escena: PackedScene) -> Image`.

### 28. `RoomBuilderUI` — UI · Escena propia · `extends Control`
**Función:** la paleta. Una pestaña por categoría más una de **estructura**, poblada de `CatalogoPiezas.PIEZAS`. Emite qué se eligió; **no coloca nada**.
**Godot nativo:** `TabContainer` con un `ItemList` por pestaña en modo icono — `ItemList` ya hace la grilla, el scroll y la selección. La API de drag & drop de `Control` queda para cuando se arrastre desde el inventario en la fase 4.
**Interactúa con:** lee `ItemDatabase.colocables()` y `CatalogoPiezas.PIEZAS`; su señal la escucha `EditorSala`.
**Funciones clave:** `refrescar() -> void`, `seleccion_actual() -> Variant`, `signal item_elegido(def: ItemDefinition)`, `signal pieza_elegida(capa: StringName, pieza: StringName)`.

### 28b. `EditorSala` — Nodo · Componente · `extends Node3D`
**Función:** traduce gestos en `OperacionSala` y se las entrega a `RoomController.aplicar()`. **Nunca toca la sala directamente** — ésa es toda la gracia.
**Godot nativo:** `_unhandled_input` para el arrastre; `IsoGrid.celda_bajo_puntero()` para el snap, sin matemática propia; `celdas_en_rectangulo()` para pintar arrastrando.
**Interactúa con:** lee la selección de `RoomBuilderUI`, alimenta `IndicadorCelda`, y su única salida es `aplicar()`. Sólo existe mientras `GameManager.editando()`.
**Funciones clave:** `_al_hacer_clic(celda: Vector2i) -> void`, `rotar() -> void`, `deshacer() -> void`.

### 4b. `RoomController` (ampliado) — el documento de sala
**Función:** `to_dict()` pasa a incluir la estructura de los dos `GridMap` **por nombre de pieza**, más `version_formato` y la versión del catálogo con que se creó. `from_dict()` la repinta. Sin esto una sala editada no sobrevive, y sin el nombre en vez del id no sobrevive a un re-export de la `MeshLibrary` (**D18**, **D24**).
**Funciones clave:** hechas. `to_dict()` incluye la estructura por nombre, `version_formato` y la versión del catálogo; `from_dict()` limpia las capas, repinta y recién después repone los muebles, y devuelve `Errores.Codigo`.

### 10b. `SaveManager` (ampliado) — salas como archivos
**Función:** `guardar_sala()` y `cargar_sala()` contra `user://salas/<nombre>.json`. No es un extra: es la persistencia canónica de una sala y lo que un servidor almacenaría. Permite compartir salas y versionar mapas.
**Godot nativo:** `JSON.stringify()`/`parse()` y `FileAccess`, igual que el guardado de partida; `DirAccess.make_dir_recursive_absolute()` para la carpeta.

### Cámara
Desplazamiento y zoom para trabajar en salas grandes. Es del `RoomController`, que ya es dueño del pivote y de la cámara.

---

## Fase 4 — Las interacciones

Que agregar una interacción sea **datos, no código**. **Listo cuando** recorrés una sala amueblada y casi todo lo que clickeás hace algo.

### 34. `PoseBehavior` — Resource · Recurso, sin escena · `extends InteractionBehavior`
**Función:** generaliza `SentarseBehavior`. `sentarse`, `sentarse_piso` y `acostarse` pasan a ser tres `.tres` del mismo script.
**Godot nativo:** `Resource` con `@export` para `animacion_entrada`/`bucle`/`salida`, `capacidad`, `offset_visual`, `giro_asiento`, `etiqueta` y `etiqueta_salir`. El pack trae las tres secuencias completas y toda la lógica difícil ya está escrita en `SentarseBehavior`: sólo hay que parametrizarla.
**Y de paso, la costura 5:** los ocupantes pasan a guardarse **por id de actor y no por nodo**. Un nodo del cliente A no existe en el B. Como igual hay que reescribir el script, el cambio es gratis ahora y carísimo después.

### 35. `LevantarBehavior` — Resource · Recurso, sin escena · `extends InteractionBehavior`
**Función:** el verbo por defecto. La mayoría de los colocables no tiene ningún verbo; un `levantar` universal los vuelve interactivos a todos de una, con la animación `PickUp`.
**Interactúa con:** `RoomController.retirar_objeto()` e `InventoryManager`. `generar_items.py` se lo agrega a todo colocable salvo exclusión explícita.

### 36. `SuperficieBehavior` — Resource · Recurso, sin escena · `extends InteractionBehavior`
**Función:** apoyar cosas encima de una mesa, un estante o un mostrador. **Es un objetivo de primer orden**, no un extra: el MVP es un sandbox de decoración y la expresividad de lo que un jugador arma es el producto.
**Lo que hay que decidir antes de escribirlo: `SISTEMAS.md` D25.** Rompe el supuesto de un objeto por celda, del que dependen `objeto_en()`, `OperacionSala.retirar(celda)` y —cuando llegue— nombrar un objeto por la red. La forma recomendada es que **lo apoyado cuelgue del `WorldObject` de abajo** y no de la grilla, porque no toca `IsoGrid` y porque «lo que está sobre la mesa se va con la mesa» es una regla que el jugador entiende sin que se la expliquen.

### 21. `ContenedorBehavior` · 37. `AlternarBehavior`
**Función:** abrir y guardar; encender y apagar. Cubren estante, alacena, cajón y lámpara.
**Godot nativo:** el contenido y el encendido viven en `WorldObject.instancia`, que ya se serializa — una lámpara encendida sigue encendida mañana, sin código de guardado nuevo.

### 38. `AbrirCrafteoBehavior` y las estaciones (antes 27, `CraftingStation`)
**Función:** estufa, fregadero, banco y tabla como `WorldObject` con este verbo. Acá se enchufa `RecipeManager`, ya escrito y probado, y desaparece la mentira de la tecla `2` del arnés de `Mundo.gd`, que hoy pasa la estación a mano.
**Godot nativo:** no hace falta una clase `CraftingStation`: un `WorldObject` con un verbo más en su lista `interacciones` alcanza, y así una estación se define en `items.json` en vez de en una escena.

### 24. `InventoryUI` — UI · Escena propia · `extends Control`
**Función:** muestra el contenido de `InventoryManager`, permite arrastrar/soltar y equipar.
**Godot nativo:** `GridContainer` para la grilla de slots, y sobre todo la **API nativa de drag & drop de `Control`** (`_get_drag_data()`, `_can_drop_data()`, `_drop_data()`) — no hay que implementar el arrastre a mano.
**Funciones clave:** `refrescar() -> void`, `_get_drag_data(pos: Vector2) -> Variant`, `_drop_data(pos: Vector2, data: Variant) -> void`.

### 26. `CraftingUI` — UI · Escena propia · `extends Control`
**Función:** lista de recetas disponibles según `RecipeDefinition` y nivel del jugador.
**Godot nativo:** `ItemList` (o `Tree` si se quieren columnas de insumos) + `Button`; la barra de progreso la alimenta el timer de `RecipeManager`.
**Funciones clave:** `mostrar_recetas(habilidad: StringName) -> void`, `_al_craftear(receta: RecipeDefinition) -> void`.

### 25. `SkillsPanelUI` (sin ranking) — UI · Escena propia · `extends Control`
**Función:** nivel y xp de cada habilidad. El ranking queda fuera del MVP porque necesita otros jugadores.
**Godot nativo:** `VBoxContainer` + un `ProgressBar` por habilidad; la señal `nivel_subido` de `SkillManager` dispara el refresco.

### 29. `EquiparBehavior` — Resource · Recurso, sin escena · `extends InteractionBehavior`
**Función:** equipar herramientas; mueve el ítem a un slot del jugador.
**Godot nativo:** el reflejo visual lo resuelve `AvatarComposer` sobre los huesos de enganche del rig (**D20**).

### Emotes
`Waving`, `Cheering` y las de herramienta. Son baratas —ya están en el pack y `AvatarComposer` ya las sabe reproducir— y son mucho de lo que hace que un sandbox social se sienta vivo.

---

## Fase 5 — La economía como contenido

Ya no es el MVP: es contenido que se suma al sandbox, sobre managers que ya existen y están probados.

### 18. `TimeManager` — Autoload · `extends Node`
**Función:** el reloj del juego, del que dependen los cultivos y los ticks de mercado.
**Godot nativo:** un `Timer` hijo en vez de contar frames en `_process`.

### 19. `GatherableNode` · 20. `CropPlot` — Nodo/Escena · `extends Area3D` / `GatherableNode`
**Función:** recolectar y plantar. Plantar es una receta cuya estación es la parcela, así que `RecipeManager` ya sirve sin cambios (por eso `PlantableData` se disolvió).
**Interactúa con:** `TimeManager` para el crecimiento; `InventoryManager` para la cosecha.

### 23. `EconomyManager` — Autoload · `extends Node`
**Función:** Ducados, precios y transacciones. `items.json` ya trae `valor_base` y las tasas de compra/venta del NPC.

### 30. `MarketStall` — Nodo/Escena · `extends WorldObject`
**Función:** puesto de venta en una sala tipo Tienda; lista los precios que fija el dueño.
**Godot nativo:** hereda la detección de interacción de `WorldObject`; la UI de compra es un `PopupPanel`, no una ventana propia.
**Funciones clave:** `listar_precio(item_id: StringName, precio: int) -> Errores.Codigo`, `comprar(actor: Node, item_id: StringName) -> Errores.Codigo`.

### 31. `NPCTrader` — Nodo · Componente · `extends Node`
**Función:** IA simple de compra/venta según oferta y demanda, para probar el balance antes de tener red real.
**Godot nativo:** un `Timer` hijo para el tick de mercado.
**Funciones clave:** `evaluar_precio(item_id: StringName) -> int`, `_al_tick() -> void`.

### 32. `MarketUI` — UI · Escena propia · `extends Control`
**Función:** tablón centralizado para descubrir precios sin visitar sala por sala.
**Godot nativo:** el nodo **`Tree`** está hecho para datos tabulares con columnas ordenables (ítem / precio / vendedor) — es la herramienta correcta acá, en vez de armar filas a mano con `HBoxContainer`.

---

## Fase 6 — Networking (fuera del MVP)

No se detalla a nivel de script todavía — es la fase donde entra un servidor autoritativo real (GDD §8, §9). Lo que sí queda anotado: `EconomyManager`, `InventoryManager`, `SkillManager` y el resto de los managers de fase 2 están **diseñados desde ya desacoplados del transporte**, específicamente para que esta fase no obligue a rediseñarlos. Sobre esta base se construye:

- **Ranking/leaderboard** y el resto de las ideas de competencia de GDD §3.4 (necesitan otros jugadores reales).
- Validación server-side de `InteractionBehavior.interactuar()` y de `RecipeManager`/`EconomyManager`, reusando exactamente la misma lógica que corre en local durante el MVP.
- **Godot nativo a evaluar cuando llegue el momento:** el motor trae `ENetMultiplayerPeer`, `MultiplayerSynchronizer` y `MultiplayerSpawner`, que cubren buena parte de la sincronización de estado sin escribir un protocolo propio.
