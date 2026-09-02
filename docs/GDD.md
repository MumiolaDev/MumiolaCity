# MumiolaCity — Documento de Diseño de Juego (GDD)

**Versión:** 0.1 (borrador inicial)
**Fecha:** 2026-09-01
**Motor:** Godot 4.x
**Fase actual:** Diseño — prototipo local (single-player) antes de multijugador

---

## 1. Visión y pilares

MumiolaCity es un clon espiritual de Habbo Hotel (salas isométricas, avatares, decoración social) fusionado con la columna vertebral de un MMORPG de habilidades tipo RuneScape: **una economía enteramente dirigida por lo que producen los jugadores**, no por tiendas del sistema.

No hay "clases". Hay **habilidades con nivel propio** que se suben usando cada una de ellas. No hay loot de monstruos como fuente principal de riqueza: la riqueza nace de **recolectar materia prima → transformarla → venderla o consumirla**, y circula entre jugadores a través de una **moneda única**.

Pilares de diseño:

1. **Todo objeto vendible lo hizo un jugador.** El servidor no vende bienes intermedios ni de lujo; como mucho compra materia prima básica como red de seguridad (ver §5).
2. **Tu casa es tu medio de producción y tu escaparate.** La sala no es solo decoración: una parcela de granja, un taller o una tienda son la misma superficie de juego que en Habbo se usaba solo para socializar.
3. **Ninguna habilidad es una isla.** Cada cadena de producción depende de al menos otra habilidad distinta para completarse, para forzar comercio en vez de que cada jugador sea autosuficiente.
4. **Progresión visible en la ciudad, no solo en una hoja de stats.** Subir de nivel debe desbloquear parcelas, recetas o puestos de mercado que otros jugadores puedan ver y visitar.

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
| Tala | Bosque de la ciudad | Madera, fibra vegetal |
| Ganadería | Parcela propia (corral) | Lana, leche, huevos |

### 3.2 Producción

| Habilidad | Consume de | Produce | Vendible como |
|---|---|---|---|
| Cocina | Agricultura, Pesca, Ganadería | Platos preparados | Consumible (buffs de energía/salud) |
| Carpintería | Tala | Muebles y estructuras | Decoración de sala (núcleo Habbo) |
| Herrería | Minería | Herramientas, armas, joyas | Equipo y accesorios |
| Costura | Ganadería, Tala (fibra) | Ropa y tocados | Cosmético de avatar (núcleo Habbo) |
| Alquimia | Agricultura, Minería (gemas) | Pociones | Consumible (buffs especiales) |

### 3.3 Habilidades de soporte

| Habilidad | Efecto al subir de nivel |
|---|---|
| Comercio | Reduce la comisión del mercado; desbloquea puestos de venta propios en tu sala |
| Construcción | Amplía tamaño y tipos de sala disponibles en tu parcela |

Ninguna habilidad de producción se autoabastece: Cocina necesita a un pescador o granjero, Costura necesita a un ganadero o leñador, etc. Esto es intencional — es lo que obliga a comerciar.

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

**Fase actual del prototipo:** single-player / local, con la economía simulada mediante NPCs — el multijugador real con servidor autoritativo y base de datos queda para una fase posterior, una vez validadas las mecánicas.

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
    world/           Sala isométrica, grilla, cámara fija
    avatar/          Avatar por capas + animaciones
    ui/               Inventario, panel de habilidades, mercado, crafteo
  art/
    sprites/          Salida del pipeline de Blender, organizada por objeto/ángulo
```

Puntos de diseño de datos clave:

- **Items, recetas y habilidades como `Resource` personalizados**, no hardcodeados: agregar contenido nuevo (una prenda, una receta) no debería requerir tocar código, solo crear un `.tres`.
- **`EconomyManager` desacoplado del transporte**: en el prototipo corre en local contra NPCs simulados; cuando llegue el multijugador real, la misma interfaz debería poder hablar con un servidor autoritativo sin rediseñar el resto del juego.

---

## 9. Roadmap de fases

| Fase | Objetivo |
|---|---|
| 0 | Este documento de diseño |
| 1 | Sistema base: avatar moviéndose en una sala isométrica, cámara fija |
| 2 | Un ciclo económico vertical completo (Agricultura → Cosecha → Cocina → Consumo) con un solo NPC comprador |
| 3 | Inventario + UI de crafteo genérica basada en `Resource` |
| 4 | Parcela y construcción de sala (decoración tipo Habbo) |
| 5 | Mercado simulado con varios NPCs de IA simple, para probar balance económico antes de meter red real |
| 6 | Networking real y persistencia (servidor autoritativo + base de datos) |

---

## 10. Decisiones pendientes

- Nombre definitivo de la moneda (se usa "Ducado" como placeholder).
- Curva exacta de experiencia por habilidad y tabla de niveles.
- Si Construcción/Comercio son habilidades independientes o mejoras ligadas a otra habilidad.
- Diseño concreto de los buffs de consumo (duración, magnitud, estacabilidad).
