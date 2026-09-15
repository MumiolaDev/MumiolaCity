# MumiolaCity — Sistemas y cómo interactúan

**Versión:** 0.4 · **Fecha:** 2026-09-15 (render 3D en tiempo real; decisiones D1, D2, D3, D7 y D11 cerradas; catálogo v0.4)
**Complementa:** [`GDD.md`](GDD.md) (qué es el juego) y [`SCRIPTS.md`](SCRIPTS.md) (qué scripts existen).
**Este documento responde otra pregunta:** *cómo se comunican esos scripts entre sí, quién es dueño de cada dato, y qué decisiones de arquitectura hay que cerrar antes de escribir código.* La referencia de clases campo por campo está en [`CLASES.md`](CLASES.md).

> **Cómo leerlo.** Las secciones §1–§4 describen la arquitectura tal como se deduce de `SCRIPTS.md`. La §5 (modelo de estado), la §6 (decisiones D1–D11) y la §7 (estado de los datos) son **nuevas**: son huecos que aparecieron al revisar el diseño en profundidad. De las once decisiones de la §6, **cinco ya están cerradas** (D1, D2, D3, D7 y D11, más el lado de datos de D5); el resto sigue como propuesta, escrita así precisamente porque cambiarlas después de implementadas sale caro.

---

## 1. Las cuatro capas y la regla de dirección

Todo el juego cabe en cuatro capas. La regla que las mantiene sanas es una sola: **las dependencias apuntan siempre hacia abajo, y lo que sube lo hace por señal.**

| Capa | Qué vive acá | Puede llamar a | Nunca conoce a |
|---|---|---|---|
| **UI** (`res://escenas/ui/`) | `InventoryUI`, `CraftingUI`, `SkillsPanelUI`, `MarketUI`, `RoomBuilderUI`, `ContextMenuUI`, `HUD` | Managers, Datos | — |
| **Mundo** (`res://escenas/mundo/`, `personaje/`) | `RoomController`, `IsoGrid`, `WorldObject`, `GatherableNode`, `CropPlot`, `CraftingStation`, `MarketStall`, `PlayerController`, `AvatarComposer` | Managers, Datos | La UI |
| **Managers** (`res://autoloads/`) | `GameManager`, `SkillManager`, `InventoryManager`, `RecipeManager`, `TimeManager`, `EconomyManager`, `SaveManager`, `ItemDatabase` | Datos, otros managers | La UI **y** el Mundo |
| **Datos** (`res://data/`) | `ItemDefinition`, `RecipeDefinition`, `SkillDefinition`, `ItemInstance`, `InteractionBehavior` y sus hijos, `GatherTable` | Nada | Todo lo demás |

**Por qué importa la regla.** Si `InventoryManager` guardara una referencia a `InventoryUI` para refrescarla, el manager dejaría de poder correr sin interfaz — y el día del servidor autoritativo (GDD §8) esa es exactamente la situación: los managers corren en una máquina que no tiene ventana. Por eso los managers **emiten señales y no llaman a nadie hacia arriba**; la UI se suscribe. Es la misma razón por la que `EconomyManager` se pide desacoplado del transporte.

**Corolario práctico:** cualquier método de un manager tiene que poder ejecutarse en una escena vacía, sin jugador ni sala cargada. Si no puede, la lógica está en la capa equivocada.

```mermaid
flowchart TD
  subgraph ui[UI · escenas/ui]
    InventoryUI; CraftingUI; SkillsPanelUI; MarketUI; RoomBuilderUI; ContextMenuUI; HUD
  end
  subgraph mundo[Mundo · escenas/mundo + personaje]
    RoomController; IsoGrid; WorldObject; GatherableNode; CropPlot; CraftingStation; MarketStall; PlayerController; AvatarComposer
  end
  subgraph mgr[Managers · autoloads]
    GameManager; ItemDatabase; SkillManager; InventoryManager; RecipeManager; TimeManager; EconomyManager; SaveManager
  end
  subgraph datos[Datos · data]
    ItemDefinition; RecipeDefinition; SkillDefinition; ItemInstance; InteractionBehavior; GatherTable
  end
  ui --> mgr
  mundo --> mgr
  mgr --> datos
  ui -. "se suscribe a señales" .-> mgr
  mundo --> datos
  ui --> datos
```

---

## 2. Grafo de dependencias entre sistemas

Quién llama a quién, en concreto. Las flechas continuas son llamadas directas; las punteadas son señales (la dirección de la señal es la del aviso, no la de la dependencia).

```mermaid
flowchart LR
  Player[PlayerController]
  Grid[IsoGrid]
  Room[RoomController]
  WObj[WorldObject]
  Gather[GatherableNode]
  Crop[CropPlot]
  Station[CraftingStation]
  Stall[MarketStall]

  GM[GameManager]
  IDB[ItemDatabase]
  Inv[InventoryManager]
  Skill[SkillManager]
  Rec[RecipeManager]
  TM[TimeManager]
  Eco[EconomyManager]
  Save[SaveManager]

  Player --> Grid
  Room --> Grid
  WObj --> Grid
  Gather --> Inv
  Gather --> Skill
  Crop --> TM
  Crop --> Inv
  Station --> Rec
  Stall --> Eco
  Rec --> Inv
  Rec --> Skill
  Rec --> IDB
  Eco --> Inv
  Eco --> IDB
  GM --> Room
  GM --> Player
  Save --> Inv
  Save --> Skill
  Save --> Eco
  Save --> TM
  Save --> GM

  Inv -. inventario_cambiado .-> UIInv[InventoryUI]
  Skill -. nivel_subido .-> UISkill[SkillsPanelUI]
  Eco -. ducados_cambiaron .-> HUD
  TM -. temporizador_cumplido .-> Crop
```

**Lo que este grafo hace evidente:**

- **`InventoryManager` es el cuello de botella de todo el juego.** Recolectar, craftear, vender, equipar, colocar un mueble y guardar la partida pasan todos por él. Es el sistema que más caro sale cambiar después, y por eso la decisión **D1** (cómo representa un slot) es la primera que hay que cerrar de las once.
- **`ItemDatabase` no estaba en el mapa de scripts original y hace falta** — ver **D10**. Sin él, `RecipeManager` no puede resolver un insumo pedido por `familia`. Ya figura en `SCRIPTS.md`, en la tabla de las once clases que ese documento no detalla.
- **`SaveManager` depende de todos los demás y nadie depende de él.** Eso es correcto: es un sumidero. Debe ser el último autoload en el orden de carga (**D9**).
- **Nadie llama al `TimeManager` salvo `CropPlot`, `ModifierStack` y `SaveManager`** — es un servicio pequeño y aislado, buen candidato a implementar temprano y olvidarse.

---

## 3. Los sistemas, uno por uno

Para cada sistema: de qué es **dueño** (el dato que solo él puede mutar), qué **no** le corresponde, y por dónde entra y sale la información. La frontera de "de qué es dueño" es lo que evita que dos sistemas mantengan copias del mismo dato que luego se desincronizan.

### 3.1 Espacio — `IsoGrid` + `RoomController`

- **Dueño de:** qué celda está ocupada por qué `WorldObject`, y cuál es el área construible de la sala.
- **No le corresponde:** saber *qué* es el objeto que ocupa la celda (eso es `ItemDefinition`), ni si el jugador tiene permiso de construir ahí (eso es `RoomController` + nivel de Construcción), ni cómo se dibuja el escenario.
- **Cómo está construido (revisado el 2026-09-15):** `IsoGrid` es un `Node3D` con dos `GridMap` hijos, `Suelo` y `Paredes`. Una celda de `GridMap` admite un solo ítem, así que pintar una pared sobre una celda de suelo la reemplazaría; la regla de composición es **suelo por dentro, paredes por fuera**, en el anillo de celdas sin suelo. La consecuencia buena es que el área caminable deja de ser un rectángulo declarado y pasa a ser *lo que está pintado*: `celda_valida()` pregunta `get_cell_item()` al suelo, y las salas irregulares salen gratis.
- **Lo que un jugador puede tocar no va nunca en un `GridMap`.** Una celda no tiene `ItemInstance`, ni `estado_runtime`, ni verbos, ni recibe clics: el `GridMap` es escenario, y todo lo colocado por un jugador es un `WorldObject` (**D3**).
- **Entra:** peticiones de ocupar/liberar desde `RoomController` y `RoomBuilderUI`. **Sale:** `esta_libre()`, y la lista de celdas bloqueadas que alimenta el `AStarGrid2D` de `PlayerController`.
- **Punto de acoplamiento a vigilar:** `IsoGrid` es la única fuente de verdad de la ocupación, pero `AStarGrid2D` mantiene su **propia** copia de celdas sólidas. Hay que reconstruirla (o parchear la celda afectada con `set_point_solid()`) cada vez que se coloca o se quita un objeto, o el jugador va a caminar atravesando muebles. Es el bug más previsible de la fase 4. La forma barata de no depender de recordarlo: que `ocupar()` y `liberar_objeto()` emitan `ocupacion_cambiada` y que `PlayerController` se suscriba. Son dos líneas escritas hoy contra una tarde de depuración dentro de seis meses.
- **`AStarGrid2D` sigue valiendo con el mundo en 3D:** opera sobre una grilla de enteros y no le importa la dimensión del render. Se le pasa `celdas_bloqueadas()` —ocupadas más las que no tienen suelo— y cada celda del resultado se convierte con `celda_a_mundo()`.

### 3.2 Identidad e inventario — `ItemDatabase` + `InventoryManager`

- **Dueño de:** el catálogo de `ItemDefinition` indexado por `id` y por `familia` (`ItemDatabase`), y las pertenencias del jugador (`InventoryManager`).
- **No le corresponde:** decidir si una receta es válida (eso es `RecipeManager`) ni cuánto vale algo (eso es `EconomyManager` leyendo `valor_base`).
- **Entra:** `agregar_item` / `quitar_item` desde recolección, crafteo, compra y venta. **Sale:** la señal `inventario_cambiado`, y consultas de disponibilidad.
- **Invariante que hay que sostener:** peso total ≤ capacidad, y ningún slot con `cantidad > stack_maximo`. Toda mutación pasa por los dos métodos públicos; nadie escribe el array por fuera.

### 3.3 Progresión — `SkillManager` + `SkillDefinition`

- **Dueño de:** xp acumulada por habilidad. El **nivel es derivado**, nunca almacenado — se calcula desde la xp. Guardar ambos es garantizar que algún día no coincidan.
- **No le corresponde:** aplicar los efectos de los desbloqueos; solo declara qué nivel se alcanzó y emite `nivel_subido`. Quien tenga que reaccionar (recetas nuevas, parcela más grande) se suscribe.
- **Entra:** `agregar_xp()` desde `GatherableNode`, `CropPlot` y `RecipeManager`. **Sale:** `nivel_de()` y la señal.

### 3.4 Transformación — `RecipeManager`

- **Dueño de:** el acto de craftear como transacción atómica. Nadie más puede consumir insumos y producir resultado.
- **No le corresponde:** la interfaz (eso es `CraftingUI`) ni dónde se craftea (eso es `CraftingStation`).
- **La transacción tiene cuatro pasos y ninguno puede quedar a medias:** validar nivel → validar y reservar insumos → esperar `tiempo_crafteo_seg` → consumir insumos y entregar resultado. Si el jugador cierra el inventario, se mueve o cambia de sala en medio de la espera, hay que decidir si se cancela y se devuelve todo. **Recomendación: consumir los insumos al inicio, no al final** — así el jugador no puede gastar la misma harina dos veces lanzando dos crafteos en paralelo, y cancelar es una devolución explícita.

### 3.5 Tiempo — `TimeManager`

- **Dueño de:** todo temporizador que deba sobrevivir a cerrar el juego. Guarda `{id: timestamp_inicio, duracion}` y compara contra `Time.get_unix_time_from_system()`.
- **La distinción que hay que respetar sin excepción:** `Timer` y `create_timer()` sirven para esperas **dentro de una sesión** (respawn de un nodo de recolección, barra de progreso de un crafteo). Cualquier cosa que deba avanzar con el juego cerrado (crecimiento de cultivos) va por timestamps. Mezclarlas produce el bug de "cerré el juego y mi manzano no creció", que se descubre tarde y obliga a reescribir.
- **Consecuencia no obvia:** si los buffs de comida van por timestamp, un jugador puede tomarse un café, cerrar el juego 4 minutos y volver con el buff casi vencido. Si van por `Timer` de sesión, el buff se pausa. **Recomendación: buffs por sesión (`Timer`), cultivos por timestamp** — el buff es una recompensa por jugar activo, el cultivo es una razón para volver mañana. Son dos incentivos distintos y merecen relojes distintos.

### 3.6 Interacción — `InteractionBehavior` + `WorldObject` + `ContextMenuUI`

- **Dueño de:** el conjunto de verbos que un objeto ofrece, y el punto único de mutación (`WorldObject.ejecutar()`).
- **La regla dura del GDD §6.1 vale la pena repetirla:** el `Resource` de comportamiento es **compartido y sin estado**. Si `SentarseBehavior.tres` guardara "quién está sentado", las cincuenta sillas de la ciudad que apuntan a ese mismo archivo compartirían ocupante. El estado va en la instancia, siempre.
- **Ese es el sistema que sostiene el pilar 6 del GDD** (el rol emerge de la interactividad, no de minijuegos): cada verbo nuevo que se agrega multiplica lo que la gente puede hacer sin que nadie escriba una escena.

### 3.7 Valor — `EconomyManager`

- **Dueño de:** los Ducados del jugador y el precio piso del comprador NPC.
- **No le corresponde:** `valor_base` — ese es un dato del ítem, y es la *referencia* de precio, no el precio. El precio real lo fija el mercado (fase 5) o el piso NPC (fase 2).
- **Falta definir:** la relación entre `valor_base` y el precio piso NPC. **Recomendación: piso = 50 % de `valor_base`, y solo para `categoria == materia_prima`** — el GDD §5 dice explícitamente que el NPC no compra bienes intermedios ni de lujo, y un piso a mitad de precio nunca compite con vender a otro jugador.

### 3.8 Persistencia — `SaveManager`

- **Dueño de:** nada propio. Es un serializador: pide su estado a cada manager y lo escribe.
- **La pregunta que decide su diseño:** ¿cada manager expone `to_dict()`/`from_dict()`, o `SaveManager` conoce las tripas de todos? Lo primero: **cada manager se serializa a sí mismo**, `SaveManager` solo orquesta. Si no, agregar un campo a `InventoryManager` obliga a tocar `SaveManager` también, y esa es la clase de acoplamiento que hace que la gente deje de guardar cosas.

---

## 4. Flujos de extremo a extremo

Los seis recorridos que cubren todo el MVP. Si estos seis funcionan, el juego funciona.

### 4.1 Recolectar

```mermaid
sequenceDiagram
  actor J as Jugador
  participant P as PlayerController
  participant G as GatherableNode
  participant B as ModifierStack
  participant T as GatherTable
  participant I as InventoryManager
  participant S as SkillManager

  J->>P: click en el nodo
  P->>P: ir_a_celda() vía AStarGrid2D
  P-->>G: llegó a rango
  G->>B: multiplicador_para("agricultura")
  B-->>G: 1.15 (pala equipada + buff)
  G->>G: espera tiempo_accion / multiplicador
  G->>T: tirar()
  T-->>G: [trigo x2, semilla_manzana x1 (5%)]
  G->>I: agregar_item(...)
  I-->>G: false si no hay espacio
  G->>S: agregar_xp("agricultura", xp)
  S-->>S: emite nivel_subido si corresponde
```

**El detalle que hay que no olvidar:** `agregar_item` puede devolver `false` (inventario lleno). Si el nodo ya consumió su recurso antes de comprobarlo, el jugador pierde el material. **Comprobar espacio antes de consumir el nodo, no después.**

### 4.2 Craftear (con insumo por familia y utensilio no consumido)

```mermaid
sequenceDiagram
  actor J as Jugador
  participant U as CraftingUI
  participant R as RecipeManager
  participant D as ItemDatabase
  participant I as InventoryManager
  participant S as SkillManager

  J->>U: elige "Café con leche"
  U->>R: puede_craftear(receta)
  R->>S: nivel_de("cocina") ≥ nivel_requerido?
  R->>D: items_de_familia("taza")
  D-->>R: [taza_madera, taza_piedra, taza_plastico]
  R->>I: ¿hay 2 granos_cafe + 1 leche + alguna taza?
  I-->>R: sí
  R-->>U: true
  J->>U: pulsa Craftear
  U->>R: craftear(receta)
  R->>I: quitar_item(granos_cafe,2) + quitar_item(leche,1)
  Note over R,I: la taza NO se quita (consume:false)
  R->>R: espera tiempo_crafteo_seg
  R->>I: agregar_item(cafe_con_leche)
  R->>S: agregar_xp("cocina", 10)
```

**Dos decisiones escondidas en este flujo.** (a) Si el jugador tiene tres tazas distintas, ¿cuál "usa" la receta? Como no se consume, da igual — salvo que se adopte **D2**, en cuyo caso sí importa muchísimo y hay que dejar elegir. (b) `puede_craftear` se llama por cada receta de la lista cada vez que se abre la UI; con 29 ítems no es problema, con 500 sí. Cachear el resultado y recalcular solo con la señal `inventario_cambiado`.

### 4.3 Plantar y cosechar (atraviesa el cierre del juego)

```mermaid
sequenceDiagram
  actor J as Jugador
  participant C as CropPlot
  participant T as TimeManager
  participant I as InventoryManager

  J->>C: plantar(semilla_manzana)
  C->>I: quitar_item(semilla_manzana, 1)
  C->>T: registrar_temporizador("crop_<uuid>", 900)
  T->>T: guarda {inicio: unix_now, duracion: 900}
  Note over J,T: el jugador cierra el juego
  Note over J,T: vuelve 20 minutos después
  J->>C: (SaveManager restauró la parcela)
  C->>T: tiempo_restante("crop_<uuid>")
  T-->>C: 0 → listo
  C->>C: muestra sprite maduro
  J->>C: cosechar
  C->>I: agregar_item(manzana)
```

**El id del temporizador tiene que ser estable entre sesiones.** No puede ser el `get_instance_id()` del nodo, que cambia al recargar. Un `uuid` generado al plantar y guardado en el `ItemInstance` de la parcela.

### 4.4 Colocar un objeto y usarlo

```mermaid
sequenceDiagram
  actor J as Jugador
  participant BU as RoomBuilderUI
  participant Gr as IsoGrid
  participant Ro as RoomController
  participant W as WorldObject
  participant CM as ContextMenuUI
  participant Be as SentarseBehavior
  participant P as PlayerController

  J->>BU: arrastra Silla desde el inventario
  BU->>Gr: mundo_a_celda(mouse)
  BU->>Gr: esta_libre(celda, tamano_grilla)
  Gr-->>BU: true
  BU->>Ro: colocar_objeto(silla, celda)
  Ro->>W: instancia y registra
  W->>Gr: ocupar(celda, tamano, self)
  Note over Gr: reconstruir AStarGrid2D
  J->>W: click
  W->>CM: mostrar_para(self, jugador)
  CM->>W: verbos_disponibles(jugador)
  W->>Be: puede_interactuar(jugador, self)
  Be-->>W: true (nadie sentado)
  CM-->>J: menú ["Sentarse"]
  J->>CM: elige Sentarse
  CM->>W: ejecutar(SentarseBehavior, jugador)
  W->>Be: interactuar(jugador, self)
  Be->>W: estado_runtime.ocupante = jugador
  Be->>P: sentarse_en(self)
```

### 4.5 Consumir y trabajar con el buff

```mermaid
sequenceDiagram
  actor J as Jugador
  participant I as InventoryManager
  participant B as ModifierStack
  participant G as GatherableNode

  J->>I: usar "Café"
  I->>B: aplicar_modificador(efecto)
  B->>B: {habilidad: manufactura, x1.10, 300s}
  I->>I: quitar_item(cafe, 1)
  J->>G: recolectar
  G->>B: multiplicador_para("manufactura")
  B-->>G: 1.10
  Note over B: al expirar, emite modificadores_cambiaron
```

### 4.6 Vender

```mermaid
sequenceDiagram
  actor J as Jugador
  participant St as MarketStall
  participant E as EconomyManager
  participant I as InventoryManager
  participant H as HUD

  J->>St: vender 10 madera
  St->>E: vender_a_npc("madera", 10)
  E->>E: precio = valor_base * 0.5 (solo materia_prima)
  E->>I: quitar_item("madera", 10)
  E->>E: ducados += 10
  E-->>H: ducados_cambiaron
```

---

## 5. Dónde vive cada dato

La tabla más importante del documento. La mayoría de los bugs de un juego de este tipo salen de tener el mismo dato en dos lugares.

| Dato | Vive en | Se persiste | Nota |
|---|---|---|---|
| Qué es una silla (peso, receta, verbos) | `ItemDefinition` (`.tres` en disco) | No — es contenido | Nunca se muta en runtime |
| Cuántas maderas tengo | `InventoryManager`, slot apilado | Sí | Sin `ItemInstance`, ver **D1** |
| Qué contiene *esta* taza | `ItemInstance.contenido_id` | Sí | El consumible **es** el contenido: no existe suelto (**D2**) |
| Quién está sentado en *esta* silla | `WorldObject.estado_runtime` | **No** | Estado de sesión, y el único sitio donde se permite una referencia a un nodo vivo (**D3**) |
| En qué celda está *esta* mesa | `IsoGrid._ocupadas` + `WorldObject.celda_origen` | Sí, vía `RoomController` | Es dato del emplazamiento, no del objeto: no va en su `ItemInstance` (**D3**) |
| Xp de Cocina | `SkillManager` | Sí | El nivel se deriva, no se guarda |
| Nivel de Cocina | *derivado* de la xp vía `SkillDefinition` | No | |
| Cuánto le falta a mi manzano | `TimeManager` (timestamp de inicio) | Sí | No un `Timer` |
| Cuánto le queda a mi café | `ModifierStack` (`Timer` de sesión) | No | Ver §3.5 |
| Mis Ducados | `EconomyManager` | Sí | |
| Precio de mercado de la madera | `EconomyManager` (fase 5) | Sí | En fase 2 es `valor_base * 0.5` |
| En qué sala estoy | `GameManager` | Sí | |

**Las dos filas que hay que mirar dos veces** son las que dicen "No" en persistencia — son, precisamente, las que viven en `estado_runtime` (**D3**): ocupante de una silla y buffs activos. Que un jugador cargue la partida y aparezca de pie al lado de la silla, sin el buff del café, es aceptable y simplifica mucho. Que aparezca *dentro* de la silla porque se guardó el ocupante pero no la animación, no lo es.

---

## 6. Decisiones de arquitectura: cinco cerradas, seis pendientes

Once decisiones que hay que cerrar antes de escribir el sistema correspondiente, ordenadas por lo caro que sale cambiarlas después. **Cinco ya están cerradas** — D1, D2 y D11 aplicadas en `items.json`, D3 resuelta acá abajo, y D7 postergada a la fase 2 a propósito — y **D5 tiene el lado de los datos hecho y el del código pendiente**. Las demás siguen abiertas.

### D1 — ¿Un `ItemInstance` por unidad, o slots apilados? · **decidida**

`SCRIPTS.md` dice que `InventoryManager` "contiene los `ItemInstance` del jugador". Pero `items.json` marca el trigo como `apilable: true, stack_maximo: 99`: 99 objetos `Resource` para representar 99 trigos idénticos es puro desperdicio de memoria y de tamaño de guardado.

**Contradicción concreta en los datos:** las seis tazas y platos son `apilable: true, stack_maximo: 10` **y** tienen campo `contenedor`. Una taza vacía y una taza servida con café no pueden ocupar el mismo stack — son objetos distintos.

**Decisión:** el inventario es un `Array[InventorySlot]`, y el slot tiene dos formas:
- **Apilado:** `{definicion, cantidad}` con `instancia == null`. Para todo lo que no tiene estado propio.
- **Único:** `{definicion, cantidad: 1, instancia: ItemInstance}`. Para lo que sí lo tiene.

Y una regla derivada, **ya aplicada en `items.json` v0.4**: si un ítem tiene `contenedor`, `apilable` es `false` y `stack_maximo` es 1. Un ítem con estado no se apila, y eso convirtió las seis tazas y platos en instancias únicas.

### D2 — ¿Dónde vive el café: en un ítem propio o dentro de la taza? · **decidida: dentro de la taza**

Hoy hay dos lecturas incompatibles del mismo diseño. `items.json` define `cafe` como un ítem con su propio `valor_base`, y la receta pide una taza que **no se consume**. Pero `lista_items.md` dice que "una Taza puede estar vacía o servida con Café" como estado de instancia. ¿El café es un ítem que tengo, o es el contenido de una taza que tengo?

- **Modelo A (café como ítem suelto):** la taza es un requisito de crafteo que se comprueba una vez y no cuesta nada. Consecuencia: **una sola taza en todo el inventario habilita cafés infinitos**, y el sistema de contenedores queda decorativo.
- **Modelo B (café dentro de la taza):** craftear café muta un `ItemInstance` de taza a `{contenido: "cafe"}`. Consumirlo devuelve la taza vacía. Consecuencia: la cantidad de cafés que puedo llevar encima **es** la cantidad de tazas que tengo, y Cocina pasa a depender de verdad de Carpintería/Manufactura.

**Decisión: modelo B.** Es el que hace cierto el pilar 3 del GDD ("ninguna habilidad es una isla") en vez de dejarlo como intención: con el modelo A, un cocinero compra una taza una vez en su vida y ya no vuelve a necesitar a nadie. Con el B, un cocinero que quiere vender veinte cafés necesita veinte tazas de alguien. Implica que el precio de venta de un consumible líquido es `valor_base(contenido) + valor_base(recipiente)`, y que `es_liquido`/`es_solido` dejan de ser una anotación y pasan a ser una regla que `RecipeManager` aplica.

**Lo que ya cambió en los datos (v0.4):** los seis utensilios son `apilable: false, stack_maximo: 1`, y el `_readme` de `items.json` documenta el contrato completo — qué ocupa el contenido, cuándo se libera y cómo se calcula el precio del conjunto. **Lo que queda por escribir es el código:** `RecipeManager.craftear()` recibe la instancia de utensilio concreta, y `ContenedorBehavior.consumir()` aplica el efecto y la vacía.

### D3 — Unificar `ItemInstance` y `WorldObject.estado_instancia` · **decidida**

**El problema.** Una misma cosa concreta del juego — *esta* taza, no "las tazas de madera" — vive alternadamente en dos sitios: dentro del inventario del jugador y colocada en una sala. Godot ofrece un contenedor natural distinto para cada sitio: un `Resource` (`ItemInstance`), que se serializa solo dentro del guardado, y una propiedad del nodo (`estado_instancia: Dictionary`), que existe mientras la sala está cargada. Si cada sitio usa el suyo, el estado no sobrevive el viaje: **dejás una taza servida sobre la mesa, la volvés a levantar y el café desapareció**, porque nadie copió el diccionario del nodo de vuelta al recurso del inventario.

**Por qué "poner todo en `ItemInstance`" tampoco funciona.** Hay estado que *no debe* sobrevivir. Quién está sentado en esta silla es un dato real mientras jugás, pero carece de sentido después de cargar la partida: el jugador ya no está ahí. Serializarlo produce sillas con un fantasma sentado, o peor, una referencia a un nodo que ya no existe. El problema nunca fue que hubiera dos contenedores — fue que **no estaban nombrados ni tenían una regla**.

**Decisión: dos contenedores, con vidas distintas y declaradas.**

| | `ItemInstance` | `estado_runtime` |
|---|---|---|
| Qué es | `Resource` con `@export` | `Dictionary` sin `@export` |
| Vive en | el archivo de guardado | la escena cargada |
| Sobrevive a | cerrar el juego | nada: muere al descargar la sala |
| Puede guardar | solo datos serializables: ids, números, textos | también referencias vivas a nodos |
| Ejemplo | qué café tiene *esta* taza; cuánto lleva creciendo *esta* semilla | quién está sentado; qué animación corre |

**La regla para decidir en cuál va un dato es una pregunta:** *¿tiene sentido que esto siga siendo cierto mañana?* Qué contiene la taza, sí. Quién está sentado, no.

**Y el corolario que atrapa el error antes de cometerlo:** `ItemInstance` **nunca** guarda una referencia a un nodo. Si un dato necesita apuntar a algo vivo, por definición es de sesión y va en `estado_runtime`. Esa sola frase evita la clase entera de bugs de "guardado que apunta a un objeto que ya no existe".

**El viaje de ida y vuelta.** `WorldObject` **posee** un `ItemInstance`, y el ciclo mundo↔inventario es mover ese mismo recurso, no copiarlo:

```
InventoryManager (slot único)
   │
   ├─ RoomController.colocar_objeto(instancia, celda)
   │     1. InventoryManager.quitar_instancia(instancia)
   │     2. WorldObject.instancia = instancia      ← el mismo recurso, no un duplicado
   │     3. IsoGrid.ocupar(celda, tamano, obj)
   │
   └─ RoomController.retirar_objeto(obj)
         1. IsoGrid.liberar_objeto(obj)
         2. InventoryManager.agregar_instancia(obj.instancia)
         3. obj.queue_free()
```

**La propiedad tiene que ser exclusiva.** Si el inventario conserva la referencia *y* el `WorldObject` también, el mismo objeto existe dos veces — es el bug de duplicación clásico, y con `Resource`, que se pasa por referencia, es facilísimo de cometer sin notarlo. Quitar del inventario y asignar al nodo son un solo paso indivisible; si el paso 2 puede fallar, el 1 se revierte.

**Dónde *no* va el estado: la colocación.** En qué celda está y hacia dónde mira son datos del **emplazamiento**, no del objeto: un mismo `ItemInstance` puede estar en distintas celdas a lo largo de su vida, y mientras está en la mochila no está en ninguna. Van en `WorldObject.celda_origen` y `rotacion_grilla`, y los persiste `RoomController.to_dict()`, no el `ItemInstance`.

**Una asimetría deliberada entre el mundo y el inventario.** En el mundo, `WorldObject.instancia` **nunca es `null`**: hasta una silla, que no tiene estado propio, lleva la suya. En el inventario, en cambio, todo lo que no tiene estado propio se guarda como stack sin instancia (**D1**). Es a propósito, y las dos mitades optimizan cosas distintas: el inventario optimiza por volumen — 99 maderas no pueden ser 99 recursos — y el mundo optimiza por uniformidad, porque 50 objetos en una sala sí pueden ser 50 recursos y a cambio **ningún script del mundo tiene que preguntar si hay instancia o no**. La conversión entre las dos formas vive en `colocar_objeto()` y `retirar_objeto()`, y en ningún otro lugar: `agregar_instancia()` colapsa a stack lo que no tiene estado propio.

**Un detalle de Godot que muerde exactamente acá.** Los `Resource` se pasan por referencia y el motor **cachea los `.tres` cargados**: hacer `load()` del mismo archivo dos veces devuelve *el mismo objeto*. Por eso un `ItemInstance` **nunca es un archivo en disco** — se crea en runtime con `.new()` y se serializa dentro del `SaveGame`, no como asset propio. Si fuera un `.tres`, dos tazas del mismo tipo compartirían contenido y servir una serviría todas. Por lo mismo, duplicar un objeto (partir un stack, craftear una taza nueva) pide un `duplicate()` explícito, nunca reasignar la referencia.

**De regalo, encaja con el multijugador (D8).** La misma partición mapea a la división cliente/servidor sin rediseñar nada: `ItemInstance` es el estado autoritativo que el servidor posee y replica; `estado_runtime` es presentación local que cada cliente reconstruye solo.

**Escenas que no vienen de un ítem.** `CraftingStation` y `MarketStall` heredan de `WorldObject`, y una mesada pública de la plaza no la colocó ningún jugador. Para que la invariante «`instancia` nunca es `null`» se sostenga sin excepciones, esas escenas llevan su `ItemInstance` creado dentro del propio `.tscn`.

### D4 — Las habilidades no pueden ser `String` sueltos · **bloquea `SkillManager` (fase 2)**

`SCRIPTS.md` define `agregar_xp(habilidad: String, ...)`. Ya hay un desync latente: el GDD escribe **Minería, Carpintería, Ganadería** con tilde, e `items.json` escribe **Mineria, Carpinteria, Ganaderia** sin tilde. El día que alguien pase el nombre del GDD, la xp se acumula silenciosamente en una habilidad que no existe, sin error.

**Propuesta:** un `const Habilidades` con `StringName` en snake_case sin tildes (`&"mineria"`) como clave única de todo el sistema, y `SkillDefinition.nombre_display` con la tilde para mostrar. Ninguna cadena literal de habilidad se escribe fuera de ese archivo.

### D5 — Un solo esquema para buffs y bonos de equipo · **datos ya corregidos · falta el código**

`items.json` los modela de dos formas distintas: el café usa `efecto: {tipo: "buff_velocidad_manufactura", magnitud: 10}` — con la habilidad **codificada dentro del nombre del tipo** — mientras que la pala usa `bono: {habilidad_afectada: "Agricultura", magnitud: 15}`, que es la forma correcta. Con el esquema del café, cada habilidad nueva obliga a inventar un `tipo` nuevo y a agregar un `if` en el código que lo interpreta.

**Aplicado en `items.json` (v0.3):** `efecto` y `bono` ya comparten exactamente la misma forma, y el buff del café dejó de codificar la habilidad dentro del nombre del tipo:
```
{ tipo: &"velocidad", habilidad_afectada: &"manufactura", magnitud: 10.0, duracion_seg: 300.0, estacable: false }
```
**Lo que queda por decidir es el lado del código:** un único punto de consulta, `ModifierStack.multiplicador_para(habilidad) -> float`, que suma el equipo equipado y los buffs activos. Hoy `GatherableNode` tendría que consultar dos sistemas distintos (el slot de herramienta y el controlador de buffs, que antes de esta decisión eran dos clases separadas) y combinarlos a mano en cada sitio donde importe la velocidad.

### D6 — Falta la tabla de drops · **bloquea `GatherableNode` (fase 2)**

`lista_items.md` dice que la Semilla de manzana se obtiene "en baja proporción" al cosechar Manzana. **Esa proporción no tiene dónde vivir:** no es un campo de `items.json` ni un recurso de `SCRIPTS.md`. Terminaría hardcodeada en un script, que es exactamente lo que el GDD §8 prohíbe.

**Propuesta:** un recurso nuevo `GatherTable` con `Array[GatherDrop]{item_id, cantidad_min, cantidad_max, probabilidad}`, y `GatherableNode.@export var tabla: GatherTable`. Es una de las once clases que `SCRIPTS.md` lista pero no detalla (firma completa en [`CLASES.md`](CLASES.md) §1.10).

### D7 — La energía no tiene sumidero · **postergada a fase 2, a propósito**

Tres de los cinco consumibles restauran energía, el `HUD` muestra una barra de energía, y **nada en todo el diseño la gasta**. Tal como está, Pan, Jugo de manzana y Huevo cocido no sirven para nada y el 60 % de la habilidad de Cocina queda sin propósito.

**Decisión: no se resuelve todavía.** La barra sigue existiendo en el `HUD` y los tres consumibles siguen restaurándola, pero nada la gasta hasta que haya un ciclo económico real que balancear. Es una postergación consciente, no un olvido: poner un coste de energía antes de saber cuántas acciones por minuto hace un jugador es elegir un número a ciegas. **La consecuencia hay que tenerla presente: hasta que se cierre, Pan, Jugo de manzana, Huevo cocido y Pescado a la plancha no tienen uso real** — se craftean, se venden y se comen sin que comer cambie nada.

**La propuesta que quedó registrada para cuando llegue el momento:** cada acción de recolección cuesta energía (≈2 puntos sobre 100), y por debajo de 20 la velocidad de recolección cae un 50 % — **penaliza, no bloquea**. Bloquear al jugador por una barra vacía es la mecánica más odiada de los juegos sociales y no hace falta: basta con que comer sea claramente mejor que no comer. Con ~50 acciones por barra llena y +20 por Pan, la comida se vuelve un consumo constante y real, que es lo que sostiene la demanda de Cocina en el mercado. El momento natural para cerrarlo es junto con el primer balanceo de la fase 2, cuando ya se pueda medir el ritmo real de juego.

### D8 — Cómo se prepara la interacción para el servidor · **decisión barata ahora, cara después**

El GDD §6.1 dice que `interactuar()` "queda listo para multijugador sin rediseño". Para que eso sea cierto tiene que cumplir dos condiciones que hoy no están escritas: **devolver éxito/fracaso** en vez de ser `-> void` (el servidor necesita poder rechazar), y **no mutar nada directamente**, sino a través de los managers, que son los que un día correrán en el host.

**Propuesta:** `interactuar(actor, objeto) -> bool`, y ninguna escritura a estado de juego desde el cuerpo del comportamiento que no pase por un manager o por `objeto.estado_runtime`.

### D9 — Orden de carga de los autoloads · **trivial, pero rompe el arranque si se equivoca**

Los autoloads se inicializan en el orden del Project Settings, y `_ready()` de uno puede necesitar a otro ya listo.

**Propuesta:** `ItemDatabase` → `TimeManager` → `SkillManager` → `InventoryManager` → `RecipeManager` → `EconomyManager` → `GameManager` → `SaveManager`. `ItemDatabase` primero porque todos leen definiciones; `SaveManager` último porque restaura sobre todos los demás; `GameManager` penúltimo porque cambiar de sala presupone que los managers ya existen.

### D10 — Falta `ItemDatabase` · **bloquea `RecipeManager` (fase 2)**

`RecipeDefinition` admite insumos pedidos por `familia` ("cualquier taza"). Para resolver eso hace falta un índice `familia -> [ItemDefinition]`, y **ningún script de `SCRIPTS.md` tiene ese trabajo asignado**. Godot no autocarga los `.tres` de una carpeta: hay que recorrerla con `ResourceLoader`.

**Propuesta:** autoload `ItemDatabase` que en `_ready()` escanea `res://data/objetos/`, y expone `obtener(id)`, `items_de_familia(familia)`, `items_de_categoria(categoria)`. Con él y `GatherTable` (D6), más los recursos anidados que hoy son diccionarios sueltos, el catálogo real sube de los 32 scripts que detalla `SCRIPTS.md` a 43 clases — el índice completo está en [`CLASES.md`](CLASES.md) §7.

### D11 — `habilidad_origen` es redundante en los ítems crafteados · **resuelta**

Verificado sobre los 29 ítems: para todo ítem con receta, `habilidad_origen` es **siempre** igual a `receta.habilidad`. Es un campo duplicado esperando a desincronizarse.

**Aplicado en `items.json` (v0.3):** `habilidad_origen` se eliminó de los 18 ítems crafteados y quedó solo en materia prima (de dónde se recolecta). Para lo crafteado, la fuente única es `receta.habilidad`.

---

## 7. Estado de los datos

Calculado sobre las 27 recetas de `items.json` v0.4, comparando `valor_base` del resultado contra la suma de `valor_base` de los insumos que sí se consumen.

### 7.0 El grafo real de la economía

Generado directamente desde `items.json`, no dibujado a mano. Flecha continua = insumo consumido (con la cantidad); flecha punteada = utensilio requerido pero **no** consumido; flecha gruesa = se planta y madura con el tiempo. Los nodos redondeados son materia prima.

```mermaid
flowchart LR
  subgraph agri[Agricultura]
    trigo([Trigo])
    semilla_manzana([Semilla de manzana])
    manzana([Manzana])
    semilla_cafe([Semilla de café])
    granos_cafe([Granos de café])
  end
  subgraph pesc[Pesca]
    pescado([Pescado])
    marisco([Marisco])
  end
  subgraph mine[Minería]
    mineral_hierro([Mineral de hierro])
    piedra([Piedra])
  end
  subgraph silv[Silvicultura]
    madera([Madera])
    resina([Resina])
    fibra_vegetal([Fibra vegetal])
  end
  subgraph gana[Ganadería]
    leche([Leche])
    huevo([Huevo])
    lana([Lana])
  end
  subgraph coci[Cocina]
    harina[Harina]
    pan[Pan]
    cafe[Café]
    jugo_manzana[Jugo de manzana]
    cafe_con_leche[Café con leche]
    huevo_cocido[Huevo cocido]
    pescado_plancha[Pescado a la plancha]
    caldo_marisco[Caldo de marisco]
  end
  subgraph carp[Carpintería]
    taza_madera[Taza de madera]
    taza_piedra[Taza de piedra]
    plato_madera[Plato de madera]
    plato_piedra[Plato de piedra]
    silla_madera[Silla de madera]
    mesa_madera[Mesa de madera]
    estanteria[Estantería]
  end
  subgraph manu[Manufactura]
    plastico[Plástico]
    taza_plastico[Taza de plástico]
    plato_plastico[Plato de plástico]
    pala_hierro[Pala de hierro]
    pico_mineria[Pico de minería]
    cana_pescar[Caña de pescar]
  end
  subgraph cost[Costura]
    hilo_lana[Hilo de lana]
    tela_fibra[Tela de fibra]
    gorro_lana[Gorro de lana]
    chaleco_lana[Chaleco de lana]
    camiseta_fibra[Camiseta de fibra]
    pantalon_fibra[Pantalón de fibra]
  end
  semilla_manzana ==>|planta 15min| manzana
  semilla_cafe ==>|planta 18min| granos_cafe
  trigo -->|3| harina
  resina -->|3| plastico
  lana -->|3| hilo_lana
  fibra_vegetal -->|3| tela_fibra
  madera -->|1| taza_madera
  piedra -->|1| taza_piedra
  plastico -->|1| taza_plastico
  madera -->|1| plato_madera
  piedra -->|1| plato_piedra
  plastico -->|1| plato_plastico
  harina -->|2| pan
  granos_cafe -->|2| cafe
  taza_madera -.->|no consume| cafe
  taza_piedra -.->|no consume| cafe
  taza_plastico -.->|no consume| cafe
  manzana -->|2| jugo_manzana
  taza_madera -.->|no consume| jugo_manzana
  taza_piedra -.->|no consume| jugo_manzana
  taza_plastico -.->|no consume| jugo_manzana
  granos_cafe -->|2| cafe_con_leche
  leche -->|1| cafe_con_leche
  taza_madera -.->|no consume| cafe_con_leche
  taza_piedra -.->|no consume| cafe_con_leche
  taza_plastico -.->|no consume| cafe_con_leche
  huevo -->|2| huevo_cocido
  plato_madera -.->|no consume| huevo_cocido
  plato_piedra -.->|no consume| huevo_cocido
  plato_plastico -.->|no consume| huevo_cocido
  pescado -->|2| pescado_plancha
  plato_madera -.->|no consume| pescado_plancha
  plato_piedra -.->|no consume| pescado_plancha
  plato_plastico -.->|no consume| pescado_plancha
  marisco -->|2| caldo_marisco
  taza_madera -.->|no consume| caldo_marisco
  taza_piedra -.->|no consume| caldo_marisco
  taza_plastico -.->|no consume| caldo_marisco
  mineral_hierro -->|2| pala_hierro
  madera -->|1| pala_hierro
  mineral_hierro -->|2| pico_mineria
  madera -->|1| pico_mineria
  madera -->|2| cana_pescar
  fibra_vegetal -->|1| cana_pescar
  hilo_lana -->|2| gorro_lana
  hilo_lana -->|3| chaleco_lana
  tela_fibra -->|2| camiseta_fibra
  tela_fibra -->|3| pantalon_fibra
  madera -->|2| silla_madera
  madera -->|4| mesa_madera
  madera -->|3| estanteria
  piedra -->|2| estanteria
```

Con las nueve habilidades cubiertas, se ven de un vistazo dos cosas. **Madera sigue siendo el material más demandado** — ocho recetas dependen de ella, contra tres de Piedra. Y **Cocina es la única habilidad que consume de otras cinco** (Agricultura, Pesca, Ganadería, Carpintería y Manufactura), lo que la convierte en el nudo del comercio: nadie cocina sin comprarle a alguien.

### 7.1 Los precios ya no se eligen: salen de una regla

En la v0.2 cuatro recetas **destruían valor** — craftearlas empobrecía al jugador respecto de vender los materiales sueltos:

| Receta | Coste insumos | `valor_base` v0.2 | Margen v0.2 | `valor_base` v0.4 | Margen v0.4 |
|---|---:|---:|---:|---:|---:|
| **Pan** | 18 Dc (2 Harina) | 8 | **−4** | 25 | +7 |
| **Plástico** | 9 Dc (3 Resina) | 8 | **−1** | 13 | +4 |
| **Taza de plástico** | 13 Dc | 7 | **−1** | 18 | +5 |
| Harina | 6 Dc (3 Trigo) | 6 | 0 | 9 | +3 |
| Plato de plástico | 13 Dc | 8 | 0 | 18 | +5 |

La causa no era ninguna de esas cinco cifras en particular: era que **cada `valor_base` se había elegido a mano**, así que nada garantizaba que el precio de un producto superara el de sus insumos. Con 42 ítems eso se sostiene revisando; con 200 no.

**La regla que sustituye a la elección a mano** (documentada en el `_readme` de `items.json`, para que sobreviva a este documento):

```
coste  = Σ valor_base(insumo) × cantidad     # solo los que se consumen; para una familia, el miembro más barato
margen = max(redondear(coste × 0.4), 3)      # todo crafteo agrega valor, con un piso de 3 Dc
valor_base = coste + margen × prima          # prima 3 para equipable y decorativo, 1 para el resto
```

Solo la materia prima conserva un precio elegido a mano — es la única capa que no se deriva de nada. Los tres términos dicen algo concreto: **el 40 %** hace que transformar siempre convenga y que las cadenas profundas paguen más (dos pasos rinden 1.4² ≈ 1.96× sobre la materia prima); **el piso de 3 Dc** evita que craftear algo barato sea trabajar gratis, que es lo que le pasaba a la Harina; y **la prima 3 sobre el margen** para bienes durables reconoce que una mesa o una pala se compran una vez, y los deja siendo el sumidero de Ducados que pide el GDD §5.

### 7.2 El orden de los materiales quedó derecho

| Material | `valor_base` | Taza que produce (v0.2 → v0.4) |
|---|---:|---|
| Piedra | 1 | 9 → **4** |
| Madera | 2 | 5 → **5** |
| Resina → Plástico | 3 → 13 | 7 → **18** |

Antes la Piedra era el material más barato del juego y producía el utensilio más caro, mientras el Plástico —el más caro— producía uno más barato: un jugador racional hacía *solo* piedra y la rama del plástico quedaba muerta. Ahora el precio del producto sigue al de su material, y el plástico es el utensilio premium que el GDD §1 dice que debería ser.

**Lo que sigue abierto es de contenido, no de precios:** el único eje que diferencia madera, piedra y plástico es cuánto cuestan. Si se quiere que los tres coexistan de verdad, la diferencia tiene que ser otra — peso, capacidad del contenedor, durabilidad — y eso hay que agregarlo a mano.

### 7.3 El desbalance que queda, y por qué no es de precios

Por minuto de crafteo, Costura parece desbocada: **Chaleco de lana 576 Dc/min**, Pantalón 396, contra 180 de la Pala. Pero ese número engaña, porque mide solo el paso de crafteo y no el tiempo de conseguir los insumos — y un chaleco se lleva 9 Lana. Medido por **Ducado de materia prima invertido**, que es la comparación honesta, los dos oficios rinden casi igual: **chaleco ×1.23, pala ×1.25**. La brecha aparente es profundidad de cadena, no un error de la regla.

Lo que sí queda raro es que **un Pan (25 Dc) valga más que una Mesa (17 Dc)**. Sale de que la cadena del pan es la más profunda del juego — 6 Trigo → 2 Harina → 1 Pan, dos pasos de 40 % — mientras la mesa es un solo paso desde la madera. La palanca para corregirlo son **las cantidades de la receta**, no los precios: bajar Harina a 2 Trigo y Pan a 2 Harina deja el pan en 20 Dc. Vale la pena decidirlo cuando se pruebe el ritmo real de juego, no antes.

### 7.4 Las nueve habilidades del GDD ya tienen contenido

La v0.2 cubría siete habilidades: faltaban **Pesca** —una de las cinco de recolección— y **Costura**, que el GDD §3.2 califica de «núcleo Habbo» por ser el cosmético de avatar. Las dos entraron en la v0.4, y el catálogo pasó de 29 a 42 ítems:

| Habilidad | Ítems nuevos |
|---|---|
| Pesca | Pescado, Marisco |
| Silvicultura | Fibra vegetal |
| Ganadería | Lana |
| Costura | Hilo de lana, Tela de fibra, Gorro de lana, Chaleco de lana, Camiseta de fibra, Pantalón de fibra |
| Cocina | Pescado a la plancha, Caldo de marisco |
| Manufactura | Caña de pescar |

Costura era el hueco más caro de dejar abierto: es la habilidad que le da contenido económico al `AvatarComposer`, que ya está planificado para la fase 1. Sus prendas son `categoria: "equipable"` con `slot` (`tocado`, `torso`, `piernas`) y **sin campo `bono`** — un equipable sin bono es cosmético puro y solo cambia una capa del avatar, sin tocar el balance.

Ninguna habilidad se autoabastece, que es el pilar 3 del GDD: Costura necesita Lana de Ganadería y Fibra vegetal de Silvicultura, y Cocina necesita a un pescador, un granjero o un ganadero **y** a un carpintero o un manufacturero por el utensilio. Y no queda ninguna materia prima ni intermedio sin una receta que lo consuma.

### 7.5 Inconsistencias menores

Estas seis ya están corregidas en el repo:

- `IMPLEMENTACION.md` hablaba de "los 34 scripts"; `SCRIPTS.md` detalla **32** (34 era el número anterior a eliminar `InputController` y `CameraController`). Las once clases restantes hasta las 43 de `CLASES.md` ya figuran también en `SCRIPTS.md`, en su propia tabla.
- `IMPLEMENTACION.md` decía "Listo para pasar a `InputController`/`PlayerController`" en el criterio de salida de `IsoGrid`, nombrando un script que el propio documento declara eliminado dos párrafos más abajo.
- `lista_items.md` daba **10 min** de crecimiento al manzano; `items.json` dice `900` segundos, o sea **15 min**.
- Los campos de presentación de `items.json` (`nombre`, `descripcion`, `fuente`) estaban sin tildes: "Cafe", "Estanteria", "Plastico", "energia". Son texto que ve el jugador, no identificadores. Ahora la convención está escrita en el `_readme` del propio archivo: **ids en ASCII, presentación con ortografía completa.**
- `efecto` y `bono` usaban esquemas distintos para lo mismo (**D5**), y `habilidad_origen` estaba duplicado en los 18 ítems crafteados (**D11**).
- Los seis utensilios eran `apilable: true, stack_maximo: 10` teniendo estado de contenedor. Corregido al cerrar **D1** y **D2**: los seis son ahora `apilable: false, stack_maximo: 1`, porque una taza vacía y una servida no pueden compartir stack.

No queda ninguna inconsistencia de datos abierta. Lo que sigue pendiente en `items.json` es una migración, no un error: los nombres de habilidad todavía se escriben `"Carpinteria"`, `"Mineria"` (capitalizados y sin tilde) donde **D4** pide `StringName` en snake_case (`&"carpinteria"`). Se aplica al implementar `SkillManager` en la fase 2, junto con la decisión.

---

## 8. Qué cerrar antes de cada fase

| Antes de empezar | Hay que tener resuelto |
|---|---|
| **Fase 1** (mundo base) | **D8** (firma de `interactuar`) y **D9** (orden de autoloads) — **D3** ya decidida |
| **Fase 2** (ciclo económico) | **D4** (id de habilidad), **D5** (el `ModifierStack`; el esquema de datos ya está hecho), **D6** (`GatherTable`), **D10** (`ItemDatabase`) — **D1**, **D2** y **D11** ya decididas |
| **Fase 2, balance** | **D7** (sumidero de energía), postergada aquí a propósito. Los precios ya están corregidos (§7.1) |
| **Fase 4** (construcción) | Sincronizar `AStarGrid2D` con `IsoGrid` en cada colocación (§3.1) |
| **Fase 5** (mercado) | Relación `valor_base` ↔ precio piso NPC (§3.7) |
