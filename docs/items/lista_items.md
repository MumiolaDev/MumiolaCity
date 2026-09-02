# Lista de ítems — MVP

> **Mantener sincronizado:** esta lista y [`items.json`](items.json) deben actualizarse juntos cada vez que se agregue, elimine o modifique un ítem. Esta versión (v0.2) profundiza la cadena: ahora hay materia prima → **intermedio** → producto, y algunos consumibles necesitan un **utensilio contenedor** además de su ingrediente principal.

## Materias primas

| Ítem | Dónde participa |
|---|---|
| Trigo | Se recolecta con Agricultura · insumo de Cocina para Harina |
| Semilla de manzana | Se recolecta con Agricultura (subproducto de cosechar Manzana) · se planta para cultivar un manzano (10 min de crecimiento) |
| Manzana | Crece en un manzano cultivado a partir de Semilla de manzana · insumo de Cocina (Jugo de manzana) |
| Semilla de café | Se recolecta con Agricultura (subproducto de cosechar Granos de café) · se planta para cultivar un cafeto (~18 min de crecimiento) |
| Granos de café | Crece en un cafeto cultivado a partir de Semilla de café · insumo de Cocina (Café) |
| Mineral de hierro | Se recolecta con Minería · insumo de Manufactura (herramientas) |
| Piedra | Se recolecta con Minería · insumo de Carpintería (Estantería, Taza y Plato de piedra) |
| Madera | Se recolecta con Silvicultura · insumo de Carpintería y Manufactura |
| Resina | Se recolecta con Silvicultura (se extrae del árbol sin talarlo) · insumo de Manufactura para Plástico |
| Leche | Se recolecta con Ganadería · insumo de Cocina para Café con leche |
| Huevo | Se recolecta con Ganadería · insumo de Cocina para Huevo cocido |

## Intermedios

Bienes crafteados que a su vez son insumo de otra receta — no son un producto final.

| Ítem | Dónde participa |
|---|---|
| Harina | Crafteo en Cocina (3 Trigo) · insumo de Cocina para Pan |
| Plástico | Crafteo en Manufactura (3 Resina) · insumo de Manufactura para Taza y Plato de plástico |

## Utensilios (contenedores)

Objetos durables de Carpintería/Manufactura. Cada uno puede portar contenido (líquido o sólido) — ver la nota de contenedores más abajo.

| Ítem | Dónde participa |
|---|---|
| Taza de madera | Crafteo en Carpintería (1 Madera) · contenedor de líquidos · familia "taza" |
| Taza de piedra | Crafteo en Carpintería (1 Piedra) · contenedor de líquidos · familia "taza" |
| Taza de plástico | Crafteo en Manufactura (1 Plástico) · contenedor de líquidos · familia "taza" |
| Plato de madera | Crafteo en Carpintería (1 Madera) · contenedor de sólidos · familia "plato" |
| Plato de piedra | Crafteo en Carpintería (1 Piedra) · contenedor de sólidos · familia "plato" |
| Plato de plástico | Crafteo en Manufactura (1 Plástico) · contenedor de sólidos · familia "plato" |

## Consumibles (Cocina)

| Ítem | Dónde participa |
|---|---|
| Pan | Crafteo en Cocina (2 Harina) · efecto instantáneo: restaura energía · venta en mercado |
| Café | Crafteo en Cocina (2 Granos de café + 1 Taza de cualquier material, **la taza no se consume**) · líquido · buff temporal: +10% velocidad de Manufactura, 5 min |
| Café con leche | Crafteo en Cocina (2 Granos de café + 1 Leche + 1 Taza de cualquier material, **la taza no se consume**) · líquido · buff temporal: +15% velocidad de Manufactura, 6 min |
| Jugo de manzana | Crafteo en Cocina (2 Manzana + 1 Taza de cualquier material, **la taza no se consume**) · líquido · efecto instantáneo: restaura energía |
| Huevo cocido | Crafteo en Cocina (2 Huevo + 1 Plato de cualquier material, **el plato no se consume**) · sólido · efecto instantáneo: restaura energía |

## Equipables (Manufactura — herramientas)

| Ítem | Dónde participa |
|---|---|
| Pala de hierro | Crafteo en Manufactura (2 Mineral de hierro + 1 Madera) · slot herramienta de mano · +15% velocidad de Agricultura |
| Pico de minería | Crafteo en Manufactura (2 Mineral de hierro + 1 Madera) · slot herramienta de mano · +15% velocidad de Minería |

## Decorativos (Carpintería)

| Ítem | Dónde participa |
|---|---|
| Silla de madera | Crafteo en Carpintería (2 Madera) · se coloca en la grilla de la sala (1×1) |
| Mesa de madera | Crafteo en Carpintería (4 Madera) · se coloca en la grilla de la sala (2×1) |
| Estantería | Crafteo en Carpintería (3 Madera + 2 Piedra) · se coloca en la grilla de la sala (2×1) |

---

**Sobre los contenedores:** una Taza puede estar vacía o servida con Café — pero eso es un *estado de una instancia concreta en el inventario/guardado*, no algo que viva en `items.json`. El diccionario solo declara que la Taza *puede* contener un líquido (`contenedor.tipo: "liquido"`) y que Café/Jugo de manzana *requieren* ese contenedor (`es_liquido: true`). El día que exista un sistema de inventario real, ahí se trackeará qué taza-instancia tiene qué adentro.

**Sobre las familias:** para no triplicar cada receta por cada material de utensilio, un insumo de receta puede pedir una `familia` ("cualquier taza", "cualquier plato") en vez de un `id` exacto. Las 3 tazas comparten familia `"taza"`; los 3 platos comparten `"plato"`.

**Cobertura del loop:** ya no quedan materias primas sin receta que las consuma — Café con leche le dio uso a Leche, y Huevo cocido a Huevo (además, es el primer consumible que le da uso real a los Platos). Los ítems marcados como cruce de habilidades son Pala de hierro, Pico de minería, Estantería, Café, Café con leche, Jugo de manzana y Huevo cocido — los cuatro últimos porque combinan una materia prima de recolección con un utensilio que puede venir de Carpintería *o* Manufactura, según qué taza o plato se use (Café con leche, además, suma una tercera habilidad: Ganadería, por la Leche).
