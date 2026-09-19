# MumiolaCity — Documento de Diseño de Juego (GDD)

**Versión:** 0.4 (render 3D en tiempo real en vez de sprites pre-renderizados; idea central explicitada)
**Fecha:** 2026-09-15
**Motor:** Godot 4.7
**Fase actual:** Fase 1 — sistema base. El diseño de fase 0 está cerrado.

---

## 1. Visión y pilares

**La idea central, en una línea: un simulador de la vida real en línea en el que participás como uno más.** No sos el elegido, no hay guion que te ponga en el centro, no hay héroe. Sos un vecino de una ciudad que funciona porque la gente que vive en ella la hace funcionar. Esa frase es la regla con la que se decide si una función entra o no entra: *¿esto hace que se parezca más a una vida compartida, o me está convirtiendo en el protagonista?*

Esa idea es la **dirección**; este documento es el **tamaño**. «Simulador de la vida real» invita al alcance infinito, y lo que hace terminable el proyecto es que el alcance lo fija el GDD: nueve habilidades, el catálogo de `items.json`, y las fases del §9. Cuando la visión y el alcance choquen, gana el alcance.

En términos de referencias, MumiolaCity es un clon espiritual de Habbo Hotel (salas isométricas, avatares, decoración social) fusionado con la columna vertebral de un MMORPG de habilidades tipo RuneScape: **una economía enteramente dirigida por lo que producen los jugadores**, no por tiendas del sistema.

**Ambientación: mundo moderno, no fantasía medieval.** A diferencia de la mayoría de los MMORPG de habilidades (que heredan la estética de gremios, herrerías y espadas de RuneScape), MumiolaCity ocurre en una ciudad contemporánea. Esto no es solo estética: condiciona directamente el nombre y el catálogo de cada habilidad de producción — por eso, por ejemplo, la habilidad que trabaja el metal se llama **Manufactura** (un taller/fábrica moderna) y no "Herrería", y por eso el plástico (vía Resina, procesada por Silvicultura) es un material intermedio de primera clase junto a la madera y la piedra. Cualquier habilidad o ítem nuevo debe evaluarse primero contra este filtro: ¿encajaría en una ciudad de hoy, o es un resabio de fantasía medieval?

No hay "clases". Hay **habilidades con nivel propio** que se suben usando cada una de ellas. No hay loot de monstruos como fuente principal de riqueza: la riqueza nace de **recolectar materia prima → transformarla → venderla o consumirla**, y circula entre jugadores a través de una **moneda única**.

Pilares de diseño:

1. **Todo objeto vendible lo hizo un jugador.** El servidor no vende bienes intermedios ni de lujo; como mucho compra materia prima básica como red de seguridad (ver §5).
2. **Tu casa es tu medio de producción y tu escaparate.** La sala no es solo decoración: una parcela de granja, un taller o una tienda son la misma superficie de juego que en Habbo se usaba solo para socializar.
3. **Ninguna habilidad es una isla.** Cada cadena de producción depende de al menos otra habilidad distinta para completarse, para forzar comercio en vez de que cada jugador sea autosuficiente.
4. **Progresión visible en la ciudad, no solo en una hoja de stats.** Subir de nivel debe desbloquear parcelas, recetas o puestos de mercado que otros jugadores puedan ver y visitar.
5. **Competencia sin combate obligatorio.** Habrá PvP, pero no bélico por defecto: los jugadores compiten entre sí a través de las mismas actividades del loop económico (velocidad de recolección/producción, dominio de mercado, calidad de sala), no matándose entre ellos. Combate real queda como una futura habilidad opcional de tipo "Deporte/Condición física" (ver §3.4), no como núcleo del juego.
6. **El rol es del jugador, no del guion.** El juego no debería necesitar minijuegos diseñados a mano para que la gente decore su sala, se cambie de ropa o socialice — eso ya lo tiene que permitir el sistema base. La prioridad es que la gran mayoría de los objetos sean **interactuables de forma genuina** (una silla se puede usar para sentarse, una taza puede contener líquido y beberse, ver §6.1): esa interactividad de base es lo que sostiene el rol social y motiva a jugar en comunidad, no un sistema de minijuegos aparte encima.

---

## 2. Loop de juego core

```
RECOLECTAR  →  TRANSFORMAR  →  VENDER / CONSUMIR  →  REINVERTIR
(granja,        (cocina,         (mercado entre       (parcela más
 mina, río,      forja,           jugadores, o          grande,
 bosque)         telar...)        consumo propio        herramientas,
                                  para un buff)          recetas nuevas)
```

Cada vuelta del loop debería subir el nivel de al menos una habilidad y dejar al jugador con algo para intercambiar. El "consumo propio" existe porque muchos productos (comida, pociones) dan **efectos temporales** que aceleran otra actividad — ej. un guiso de granja sube brevemente la velocidad de minado — cerrando el círculo entre categorías.

---

## 3. Habilidades

Dos familias: **Recolección** (obtienen materia prima del mundo) y **Producción** (transforman materia prima de una o más habilidades de recolección en bienes vendibles). Cada habilidad sube de nivel usándola; el nivel desbloquea recetas y zonas de recolección más avanzadas.

### 3.1 Recolección

| Habilidad | Dónde se practica | Produce |
|---|---|---|
| Agricultura | Parcela propia (granja) | Fruta, verdura, grano |
| Pesca | Muelle / río de la ciudad | Pescado, marisco |
| Minería | Minas públicas | Mineral, piedra, gemas en bruto |
| Silvicultura | Bosque gestionado de la ciudad | Madera, resina, fibra vegetal |
| Ganadería | Parcela propia (corral) | Lana, leche, huevos |

> Nota de nombre: "Silvicultura" (gestión forestal, incluye extraer resina sin talar) reemplaza a "Tala" — no solo corta árboles, también los cultiva y explota sin destruirlos, lo cual encaja mejor con un bosque gestionado por la ciudad que con una tala libre.

### 3.2 Producción

| Habilidad | Consume de | Produce | Vendible como |
|---|---|---|---|
| Cocina | Agricultura, Pesca, Ganadería | Platos preparados | Consumible (buffs de energía/salud) |
| Carpintería | Silvicultura | Muebles y estructuras | Decoración de sala (núcleo Habbo) |
| Manufactura | Minería, Silvicultura (resina→plástico) | Herramientas, utensilios, piezas | Equipo y accesorios |
| Costura | Ganadería, Silvicultura (fibra) | Ropa y tocados | Cosmético de avatar (núcleo Habbo) |

> Nota de nombre: "Manufactura" reemplaza a "Herrería" — es un taller/fábrica moderno, no una forja, y por eso cubre tanto metal (mineral de hierro) como bioplástico (resina procesada).
>
> Se eliminó "Alquimia" (antes evaluada como "Química") de este documento: el MVP no necesita esa quinta habilidad de producción todavía. Si más adelante hace falta una fuente de consumibles con efectos especiales que no encaje en Cocina, se puede reintroducir — con nombre moderno — como habilidad nueva en vez de forzarla ahora.

### 3.3 Habilidades de soporte

| Habilidad | Efecto al subir de nivel |
|---|---|
| Comercio | Reduce la comisión del mercado; desbloquea puestos de venta propios en tu sala |
| Construcción | Amplía tamaño y tipos de sala disponibles en tu parcela |

Ninguna habilidad de producción se autoabastece: Cocina necesita a un pescador o granjero, Costura necesita a un ganadero o leñador, etc. Esto es intencional — es lo que obliga a comerciar.

> **Estado de los datos (catálogo v0.5).** Las nueve habilidades siguen siendo el alcance de diseño, pero **el MVP implementa tres**: Agricultura, Cocina y Carpintería. No es un recorte de ambición sino de assets — el catálogo se reconstruyó partiendo de los modelos 3D que el proyecto tiene, y no hay árbol, veta, pez ni animal que modele el origen de las otras seis.
>
> Pesca y Minería son las que más cerca están: sus animaciones completas ya vienen en el pack, y les falta solo el modelo del recurso. Silvicultura, Ganadería, Manufactura y Costura esperan contenido. Comercio y Construcción siguen sin ítems y es correcto: no producen, modifican reglas.
>
> Las cadenas que el MVP no cubre se resuelven comprando al NPC — pan, queso, carne, jamón y madera. A medida que una habilidad consiga sus modelos, alcanza con darle receta a esos ítems y ponerles `comprable: false`.

### 3.4 Competencia entre jugadores (PvP sin combate)

No hay guerra ni PvE de monstruos como fuente de riqueza (ver pilar 5, §1). La competencia entre jugadores ocurre **a través de las mismas habilidades del loop económico**, no de un sistema de combate aparte.

**El MVP no incluye ninguna forma de PvP.** El MVP es offline/single-player (§8) y un ranking necesita otros jugadores reales para tener sentido — no hay con quién competir todavía. Esta sección completa queda como diseño para la fase 6 (networking) en adelante: primero la mecánica base de cada habilidad tiene que funcionar bien por sí sola, y recién sobre eso tiene sentido construir competencia.

**Ideas para cuando exista multijugador (no diseñar todavía, solo dejar registradas):**
- Ranking/tablero de posiciones por habilidad (nivel y/o xp total) — la forma más simple, primera candidata a implementar en cuanto haya red.
- Eventos cronometrados de recolección o crafteo (carreras contra otros jugadores o contra el reloj) — ej. un concurso de cocina o de crafteo.
- Dominio de mercado (quién mueve más volumen o gana más Ducados en una ventana de tiempo).
- Concursos de diseño de sala, votados por otros jugadores — aunque esto, más que una "competencia" diseñada, es probablemente algo que emerge solo si el sistema de interactividad (§6.1) es suficientemente bueno.

**Combate como habilidad futura, no como núcleo:** más adelante podría agregarse una habilidad de **Deporte / Condición física** que introduzca competencia física opcional (posiblemente PvP directo), separada del resto de las habilidades de recolección/producción y sin afectar la economía central si un jugador decide no participar de ella.

---

## 4. Cadena económica de ejemplo

```
Agricultura          Ganadería
  (fruta)      +       (leche)
      \                 /
       \               /
          COCINA (jugador B)
                |
                v
        "Tarta de la huerta"
                |
        se vende en el mercado
                |
                v
       consumida por jugador C
                |
                v
     +15% velocidad de Minería
       durante 10 minutos
```

Este es el patrón que se repite en todas las cadenas: **recolector A + recolector B → productor C → mercado → consumidor D**, con un efecto que empuja a D hacia otra actividad recolectora, retroalimentando el ciclo.

---

## 5. Moneda y mercado

- **Moneda única:** el **Ducado** (`Dc`). No hay monedas premium separadas — mantiene una sola economía legible.
- **Fuentes de Ducados:** vender en el mercado de jugadores; venta de emergencia de materia prima básica a un comprador NPC a precio deliberadamente bajo (evita que la economía se congele si nadie compra, pero nunca compite con vender a otro jugador).
- **Sumideros de Ducados** (para que la moneda no se infle sin control): ampliar la parcela, comisión de Comercio en cada venta, recetas avanzadas, cosméticos de decoración de alta gama.

**Los precios de referencia no se eligen a mano.** Desde la v0.4 de `items.json`, el `valor_base` de todo ítem crafteado se deriva de sus insumos:

```
coste  = Σ valor_base(insumo) × cantidad     # solo los que se consumen
margen = max(redondear(coste × 0.4), 3)
valor_base = coste + margen × prima          # prima 3 para equipable y decorativo, 1 para el resto
```

Solo la materia prima tiene precio elegido. Esto garantiza tres cosas que antes no se cumplían: **transformar siempre agrega valor** (había cuatro recetas que empobrecían al jugador), **las cadenas profundas pagan más** que las cortas, y **los bienes durables son el sumidero**, porque su margen vale el triple. Al agregar una receta nueva hay que recalcular con la regla, no inventar un número — es lo único que evita que el problema vuelva.
- **Mercado:** puestos de venta dentro de la propia sala del jugador (visitar la tienda de alguien es, literalmente, visitar su sala — otro punto de unión directo con Habbo) más un tablón de anuncios centralizado para descubrir precios.

En la fase de prototipo (single-player, ver §8) el mercado se simula con NPCs de IA simple que compran/venden según oferta y demanda, para poder probar el balance económico antes de invertir en red real.

---

## 6. Salas y propiedades

Núcleo heredado de Habbo, reinterpretado como infraestructura productiva:

- **Parcela inicial** pequeña y gratuita; se amplía con Ducados o nivel de Construcción.
- **Tipos de sala:**
  - *Vivienda* — decoración social pura, mobiliario de Carpintería.
  - *Producción* — granja, corral, taller; aquí se practican las habilidades de recolección/transformación propias.
  - *Tienda* — puestos de venta directos, visitable por otros jugadores igual que una sala social.
- Visitar la sala de otro jugador permite ver su producción, comprarle directo (sin pasar por el tablón central) y socializar — la misma mecánica de "visita" de Habbo, ahora con una razón económica para hacerlo.

### 6.1 Interactividad de objetos (base del rol)

Requisito de diseño explícito: **la gran mayoría de los objetos del juego deben ser interactuables**, no solo decorativos. Una silla se puede usar para sentarse, una taza puede contener y servir un líquido, y así con el resto — esto es lo que le da al jugador material real para rolear, sin que el juego tenga que scriptear una escena para cada situación social.

**Decisión de arquitectura: sistema genérico/scriptable por composición de `Resource`, no un catálogo cerrado de verbos hardcodeados y no herencia de nodos por tipo de objeto.**

- `InteractionBehavior` — clase base (`Resource`, `class_name`) con `verbo`, `puede_interactuar(actor, objeto) -> bool` e `interactuar(actor, objeto) -> void`. Cada comportamiento concreto (`SentarseBehavior`, `ContenedorBehavior`, `EquiparBehavior`...) es una subclase pequeña y reutilizable de esto.
- `ItemDefinition` gana un campo `interacciones: Array[InteractionBehavior]`. Agregar un verbo a un ítem nuevo casi nunca pide código: se arrastra un `.tres` de comportamiento ya existente (ej. el mismo `SentarseBehavior.tres` sirve para todas las sillas) al array del ítem, en línea con el principio de §8 de que contenido nuevo no debería requerir tocar código.
- `WorldObject` — el nodo que representa un objeto colocado en una sala — expone `verbos_disponibles(actor)` (filtra `interacciones` por `puede_interactuar`) y `ejecutar(behavior, actor)` como único punto de entrada para mutar estado.
- **Regla dura para no romper esto:** `InteractionBehavior` es **sin estado y compartido** entre todas las instancias del mismo tipo de objeto (varias sillas de madera pueden apuntar al mismo `.tres`). Todo estado propio de una instancia concreta (quién está sentado en *esta* silla, qué líquido tiene *esta* taza servida) vive en `WorldObject.estado_instancia`, nunca en el `Resource` de comportamiento — es la misma distinción que ya hace la nota de contenedores en `lista_items.md` (el ítem declara que *puede* contener algo; qué contiene una instancia concreta es dato de guardado).
- Interacciones de a dos o más (una banca) se resuelven con el mismo patrón — `estado_instancia` guarda una lista de ocupantes con capacidad, en vez de un solo valor — sin cambiar la arquitectura.
- Como `interactuar()` es el único punto que muta estado, queda listo para multijugador sin rediseño: el mismo método se valida y ejecuta server-side el día que exista servidor autoritativo, igual que se planteó para `EconomyManager` en §8.

Pendiente, no bloqueante: decidir objeto por objeto (a medida que se agreguen a `items.json`) qué verbos concretos tiene cada uno — esto no es una decisión de arquitectura, es contenido.

---

## 7. Dirección de arte y render

**Decisión (revisada el 2026-09-15): mundo 3D en tiempo real con cámara ortográfica isométrica.** Reemplaza a la decisión original de sprites 2.5D pre-renderizados desde Blender.

**Por qué cambió.** La versión 0.3 de este documento eligió sprites pre-renderizados por tres motivos: velocidad para producir el volumen de contenido de un Habbo-like, rendimiento en salas cargadas, y compatibilidad con el avatar por capas. Dos de los tres se debilitaron al conseguir una base de modelos 3D libres:

- **Volumen de contenido:** con packs CC0 ya modelados, obtener un mueble nuevo es arrastrar un `.gltf`, mientras que la ruta de sprites exige además modelar, renderizar en cada ángulo y armar el atlas. El 3D pasó a ser el camino rápido, no el lento.
- **Rendimiento:** un centenar de mallas planas de pocos polígonos en una sala no es un problema en escritorio con hardware actual. Con móvil como segundo objetivo (**D17**), la geometría de baja densidad sigue siendo la elección correcta de todos modos.
- **Avatar por capas:** este sí sigue en pie como requisito (ver abajo), pero en 3D se resuelve con `BoneAttachment3D` en vez de componer capas de sprites por cada ángulo, que es menos trabajo y no más.

**Lo que el cambio simplifica.** La proyección isométrica deja de ser una propiedad del mundo y pasa a ser un ángulo de cámara: no hay matemática 2:1, ni `TileSet` isométrico, ni conversión propia de coordenadas. El orden de dibujo lo resuelve el búfer de profundidad, así que **desaparece todo el sistema de y-sort** y la clase de bugs asociada.

**Meta estética:** un aspecto **3D retro y acogedor**, de baja poligonización y sombreado plano. Más adelante se va a experimentar con post-procesado —posiblemente renderizar la escena a un `SubViewport` de baja resolución y escalarla con vecino más cercano, para un acabado cercano al pixel art. Eso es trabajo de fase avanzada: **primero funcionan los sistemas, después se ve bien.** La única precaución que se toma desde ya es mantener el mundo 3D en su propio `SubViewport` con la interfaz fuera de él, para que ese cambio sea una propiedad y no una reestructuración.

**Base de modelos:** packs **KayKit** de Kay Lousberg, licencia **CC0** (uso comercial libre, atribución opcional). Prototype Bits para el escenario, Furniture Bits para el mobiliario y Character Animations para el avatar. Los originales viven fuera del proyecto; a `res://arte/modelos_3d/` se copia solo el formato glTF.

**Escala: 1 celda de grilla = 1 metro = 1 unidad de Godot.** Los modelos de KayKit están autorizados en metros con el origen en la base, centrado en X y Z, así que colocar un objeto en una celda es asignarle la posición que devuelve `IsoGrid.celda_a_mundo()`, sin corrección. Con esa escala, una silla ocupa una celda, una mesa mediana 2×2 y una cama doble 3×3 — coherente con los `tamano_grilla` de `items.json`.

**Cámara:** un `Node3D` pivote en el centro de la sala con la `Camera3D` como hija:

```
Pivote (Node3D)     rotation = (-35.264, 45, 0)   # isométrico verdadero
└── Camera3D        projection = Orthogonal
                    size = 12                      # altura visible en metros
```

Montarla así, y no como cámara suelta, es lo que hace que **rotar la sala en pasos de 90° al estilo Habbo** sea una interpolación sobre `pivote.rotation.y`.

**El avatar por partes sigue siendo un requisito**, porque la ropa de Costura es mercancía comerciable y tiene que verse puesta. En 3D eso significa mallas intercambiables sobre el esqueleto del avatar, no capas de sprites compuestas por ángulo.

**El maniquí de KayKit ya trae esa estructura:** son seis mallas separadas pesadas al mismo esqueleto (`ArmLeft`, `ArmRight`, `Body`, `Head`, `LegLeft`, `LegRight`), así que los slots tienen a qué mapear — `Body` al torso, las dos piernas a piernas, `Head` a cabeza. El esqueleto además expone huesos de enganche tipo `handslot.l`, que son el punto donde van a colgar la Pala, el Pico y la Caña de pescar cuando llegue `EquiparBehavior`. **Lo que falta es contenido, no arquitectura:** el pack libre no trae prendas alternativas que ponerle, así que hasta conseguirlas Costura no tiene efecto visible.

**El pipeline de sprites no está descartado, está pospuesto.** Si algún día el rendimiento o la dirección de arte lo piden, la matemática de cámara ya es la misma y hornear los modelos a sprites —desde Blender o desde un `SubViewport` de Godot— no invalida nada de lo construido.

---

## 8. Arquitectura técnica (Godot)

**Fase actual del prototipo:** single-player / **offline**, con la economía simulada mediante NPCs — el multijugador real con servidor autoritativo y base de datos queda para una fase posterior, una vez validadas las mecánicas. La visión final del proyecto **es un juego en línea**; el hecho de que el MVP sea offline es una decisión de secuencia, no de alcance — por eso `EconomyManager` (y en general cualquier sistema que en el futuro deba sincronizarse entre jugadores) se diseña desde ya desacoplado del transporte, para no tener que rediseñarlo cuando llegue la red real.

**Render:** el mundo es 3D en tiempo real con cámara ortográfica isométrica (ver §7). El escenario estático —suelos y paredes— se pinta desde el editor con **dos `GridMap` separados**, uno por capa, porque una celda de `GridMap` solo admite un ítem y pintar una pared sobre una celda de suelo la reemplazaría. Regla de composición de la sala: **el suelo se pinta entero, también debajo de las paredes**, y la capa de paredes se pinta encima. Una pared sin losa debajo queda flotando y la sala se ve desconectada del piso, así que el anillo del perímetro lleva suelo igual que el interior.

Eso significa que «¿se puede caminar acá?» **no** es «¿hay suelo pintado acá?»: es «hay suelo **y** no hay una pieza de pared que bloquee», que es exactamente lo que comprueba `IsoGrid.esta_libre()`. La excepción son las piezas declaradas en `piezas_transitables` —`espacio_puerta` entre ellas—, que son visualmente muro pero se atraviesan: **dibujar y bloquear son cosas distintas** y no conviene deducir una de la otra (**D15**).

**Lo que un jugador puede tocar nunca va en el `GridMap`.** Una celda de `GridMap` no tiene `ItemInstance`, ni `estado_runtime`, ni verbos, ni puede recibir un clic: meter ahí una silla rompe **D3**. El `GridMap` es escenario; todo lo colocado por un jugador es un `WorldObject`.

**Plataforma: PC primero, móvil después, Web descartada (D17).** La exportación nativa de escritorio (Windows/Linux) es el objetivo del MVP y el destino principal del juego. Móvil queda como segundo objetivo, no como equivalente: el diseño —inventario, mercado, construcción de salas, chat— es de sesiones largas con teclado y mouse. **Web (HTML5) queda fuera del alcance**, con la consecuencia técnica de que el proyecto se queda en **Forward+** y conserva la niebla volumétrica, SDFGI y el desenfoque de profundidad.

Cuando llegue el momento de exportar a móvil, el ajuste es una sola clave de `project.godot`: `rendering/renderer/rendering_method.mobile = "mobile"`. Dejar que un export de Android use Forward+ es el error de renderizado más común de Godot 4 — no es una versión mejor del renderizador Mobile, es una tubería de escritorio que rinde peor en teléfonos.

**Mundo mínimo del MVP:** el prototipo necesita, como mínimo, dos espacios navegables (ver §6):

1. **Área común** — un espacio compartido tipo "plaza" que sirve de mundo (aunque en el MVP offline la comparta solo el jugador con NPCs, se diseña ya como el espacio que en el futuro será compartido entre jugadores reales).
2. **Sala privada** — la parcela/sala propia del jugador, donde puede construir y decorar libremente.

Estructura de carpetas propuesta:

Estructura real del proyecto (nombres en español, como el resto del código):

```
res://
  autoloads/            GameManager, SkillManager, InventoryManager,
                         EconomyManager (simulado), SaveManager
  nucleo/               Definiciones compartidas sin escena ni estado: Errores
                         (codigos de rechazo) y CatalogoPiezas (contrato de MeshLibrary)
  data/
    objetos/             items.json + lista_items.md (fuente) y los .tres de ItemDefinition
    recetas/             Recursos .tres: RecipeDefinition (insumos, resultado, habilidad, xp)
    habilidades/         Recursos .tres: SkillDefinition (curva de xp, desbloqueos por nivel)
    mesh_librarys/       Una escena fuente y una .meshlib por capa (D18): suelos y paredes
  herramientas/         Scripts de editor (EditorScript), no corren en el juego
  escenas/
    mundo/               IsoGrid, RoomController, Mundo y el indicador de celda
      salas/             Una escena por sala: SalaComun, SalaPrivada…
    personaje/           Avatar y animaciones
    ui/                  Inventario, panel de habilidades, mercado, crafteo
    objetos/
      generadas/         Una escena por item colocable, generada por el importador
  arte/
    modelos_3d/          Modelos glTF por familia: prototipo, muebles, restoran, avatar
    sprites/             Reservada por si vuelve el pipeline de pre-renderizado (§7)
```

Puntos de diseño de datos clave:

- **No reimplementar lo que Godot ya trae.** Antes de escribir cualquier sistema, revisar si el motor ya lo resuelve con un nodo, un recurso o una API, y apoyarse en eso; se escribe a mano únicamente la lógica específica de este juego (inventario, recetas, economía, ocupación de celdas) o lo que el motor genuinamente no cubre. Esto no es solo ahorro de trabajo: lo nativo ya está probado, integrado con el editor y mantenido por el motor. `docs/SCRIPTS.md` declara, script por script, qué parte le delega a Godot y qué parte es código propio; `docs/SISTEMAS.md` desarrolla cómo se comunican esos sistemas entre sí y qué decisiones de arquitectura siguen abiertas, y `docs/CLASES.md` fija la firma de cada clase.
- **`items.json` es la única fuente del catálogo.** Los `.tres` de `data/objetos/definiciones/` y las escenas de `escenas/objetos/generadas/` **se generan** con `herramientas/ImportarItems.gd`, un `EditorScript` que se corre desde el editor. Editarlos a mano funciona hasta la próxima importación, que los pisa — y eso es intencional. Con dos fuentes, editar una y olvidar la otra es cuestión de tiempo, y el desfase no da error: el juego simplemente usa valores viejos. Además `herramientas/generar_items.py` valida el JSON entero antes de escribirlo, y esa validación se perdería si el catálogo se editara después en el inspector.
- **Items, recetas y habilidades como `Resource` personalizados**, no hardcodeados: agregar contenido nuevo (una prenda, una receta) no debería requerir tocar código, solo crear un `.tres`.
- **`EconomyManager` desacoplado del transporte**: en el prototipo corre en local contra NPCs simulados; cuando llegue el multijugador real, la misma interfaz debería poder hablar con un servidor autoritativo sin rediseñar el resto del juego.

---

## 9. Roadmap de fases

| Fase | Objetivo |
|---|---|
| 0 | Este documento de diseño |
| 1 | Sistema base: avatar moviéndose entre el área común y su sala privada, ambas isométricas, cámara fija |
| 2 | Un ciclo económico vertical completo (Agricultura → Cosecha → Cocina → Consumo) con un solo NPC comprador |
| 3 | Inventario + UI de crafteo genérica basada en `Resource` |
| 4 | Parcela y construcción de sala (decoración tipo Habbo) |
| 5 | Mercado simulado con varios NPCs de IA simple, para probar balance económico antes de meter red real |
| 6 | Networking real y persistencia (servidor autoritativo + base de datos) |
