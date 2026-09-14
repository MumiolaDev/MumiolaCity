# MumiolaCity — Documento de Diseño de Juego (GDD)

**Versión:** 0.3 (las nueve habilidades con contenido real en `items.json` v0.4; precios derivados de una regla)
**Fecha:** 2026-09-06
**Motor:** Godot 4.x
**Fase actual:** Diseño — prototipo local (single-player) antes de multijugador

---

## 1. Visión y pilares

MumiolaCity es un clon espiritual de Habbo Hotel (salas isométricas, avatares, decoración social) fusionado con la columna vertebral de un MMORPG de habilidades tipo RuneScape: **una economía enteramente dirigida por lo que producen los jugadores**, no por tiendas del sistema.

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

> **Estado de los datos:** las nueve habilidades de §3.1–§3.2 tienen contenido real en `items.json` desde la v0.4 — Pesca aporta Pescado y Marisco, y Costura la cadena Lana/Fibra vegetal → Hilo y Tela → prendas. Las prendas son `equipable` con `slot` (`tocado`, `torso`, `piernas`) y **sin bono**: cosmético puro, que es lo que le da contenido económico al avatar por capas de §7 sin tocar el balance. Comercio y Construcción siguen sin contenido, y es correcto: no producen ítems, modifican reglas.

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

## 7. Dirección de arte

**Decisión: isométrico 2.5D con sprites pre-renderizados desde Blender**, no 3D en tiempo real con cámara fija.

Motivo resumido (detalle completo discutido con el usuario): mayor velocidad para producir el volumen de contenido que exige un Habbo-like (cientos de muebles/prendas), mejor rendimiento que geometría 3D en salas cargadas de objetos, y compatibilidad directa con el patrón de **avatar por capas** que necesita la economía de ropa vendible.

**Pipeline propuesto:**

1. Modelar cada objeto/prenda una vez en Blender.
2. Renderizar cada modelo en los mismos 4–8 ángulos isométricos fijos (batch script de Blender).
3. Exportar a atlas de sprites (PNG con alpha) por objeto.
4. En Godot: objetos de sala como `Sprite2D`/`AnimatedSprite2D` sobre una grilla isométrica; avatar como conjunto de capas (`cuerpo`, `torso`, `piernas`, `cabeza`, `tocado`) compuestas en el mismo ángulo, igual que Habbo compone su "figure data".
5. Profundidad visual: `y-sort` por la posición en la grilla, no por capas manuales.

Referencia de patrón de composición por capas: el propio Habbo y, para el sistema de tiles con profundidad apilable (paredes/muebles/techos), el motor de Project Zomboid — aunque Zomboid dibuja sus tiles a mano, no los pre-renderiza.

---

## 8. Arquitectura técnica (Godot)

**Fase actual del prototipo:** single-player / **offline**, con la economía simulada mediante NPCs — el multijugador real con servidor autoritativo y base de datos queda para una fase posterior, una vez validadas las mecánicas. La visión final del proyecto **es un juego en línea**; el hecho de que el MVP sea offline es una decisión de secuencia, no de alcance — por eso `EconomyManager` (y en general cualquier sistema que en el futuro deba sincronizarse entre jugadores) se diseña desde ya desacoplado del transporte, para no tener que rediseñarlo cuando llegue la red real.

**Plataforma:** exportación nativa de escritorio (Windows/Linux) es el objetivo del MVP — es la que se prueba primero y con la que se valida que el juego funciona. Exportación **Web (HTML5)** es una meta secundaria, deseable pronto porque facilita mostrar el proyecto a otras personas sin que instalen nada, pero no bloquea el desarrollo inicial: funcionar en escritorio es suficiente por ahora.

**Mundo mínimo del MVP:** el prototipo necesita, como mínimo, dos espacios navegables (ver §6):

1. **Área común** — un espacio compartido tipo "plaza" que sirve de mundo (aunque en el MVP offline la comparta solo el jugador con NPCs, se diseña ya como el espacio que en el futuro será compartido entre jugadores reales).
2. **Sala privada** — la parcela/sala propia del jugador, donde puede construir y decorar libremente.

Estructura de carpetas propuesta:

```
res://
  autoloads/        GameManager, SkillManager, InventoryManager,
                     EconomyManager (simulado), SaveManager
  data/
    items/           Recursos .tres: ItemDefinition (id, categoría, stack, valor base)
    recipes/         Recursos .tres: RecipeDefinition (insumos, resultado, habilidad, xp)
    skills/          Recursos .tres: SkillDefinition (curva de xp, desbloqueos por nivel)
  scenes/
    world/           Área común + sala privada, ambas isométricas sobre grilla, cámara fija
    avatar/          Avatar por capas + animaciones
    ui/               Inventario, panel de habilidades, mercado, crafteo
  art/
    sprites/          Salida del pipeline de Blender, organizada por objeto/ángulo
```

Puntos de diseño de datos clave:

- **No reimplementar lo que Godot ya trae.** Antes de escribir cualquier sistema, revisar si el motor ya lo resuelve con un nodo, un recurso o una API, y apoyarse en eso; se escribe a mano únicamente la lógica específica de este juego (inventario, recetas, economía, ocupación de celdas) o lo que el motor genuinamente no cubre. Esto no es solo ahorro de trabajo: lo nativo ya está probado, integrado con el editor y mantenido por el motor. `docs/SCRIPTS.md` declara, script por script, qué parte le delega a Godot y qué parte es código propio; `docs/SISTEMAS.md` desarrolla cómo se comunican esos sistemas entre sí y qué decisiones de arquitectura siguen abiertas, y `docs/CLASES.md` fija la firma de cada clase.
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
