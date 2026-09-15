# Lista de ítems — MVP

> **Mantener sincronizado:** esta lista y [`items.json`](items.json) deben actualizarse juntos cada vez que se agregue, elimine o modifique un ítem. Esta versión (v0.4) cierra el catálogo del MVP sobre las **nueve habilidades del GDD**: incorpora Pesca y Costura, hace que los utensilios sean instancias no apilables (un consumible líquido o sólido va *dentro* de un utensilio, no suelto) y deriva todos los precios de una regla en vez de elegirlos a mano.

> **Los precios no se eligen:** `valor_base` de un ítem crafteado sale de `coste + margen × prima`, con `margen = max(coste × 0.4, 3)` y prima 3 para bienes durables (equipables y decorativos, el sumidero de Ducados del GDD §5). Solo la materia prima tiene precio elegido a mano. Al agregar una receta hay que recalcular, no inventar un número.

## Materias primas

| Ítem | Dc | Dónde participa |
|---|---:|---|
| Trigo | 2 | Se recolecta con Agricultura · insumo de Cocina (Harina) |
| Semilla de manzana | 2 | Se recolecta con Agricultura (en baja proporción, al cosechar Manzana) · se planta para obtener Manzana tras 15 min |
| Manzana | 3 | Crece en un manzano plantado desde Semilla de manzana (Agricultura) · insumo de Cocina (Jugo de manzana) |
| Semilla de café | 3 | Se recolecta con Agricultura (en baja proporción, al cosechar Granos de café) · se planta para obtener Granos de café tras 18 min |
| Granos de café | 4 | Crecen en un cafeto plantado desde Semilla de café (Agricultura) · insumo de Cocina (Café, Café con leche) |
| Mineral de hierro | 5 | Se recolecta con Minería · insumo de Manufactura (Pala de hierro, Pico de minería) |
| Piedra | 1 | Se recolecta con Minería · insumo de Carpintería (Estantería, Plato de piedra, Taza de piedra) |
| Madera | 2 | Se recolecta con Silvicultura · insumo de Carpintería y Manufactura (Caña de pescar, Estantería, Mesa de madera, Pala de hierro, Pico de minería, Plato de madera, Silla de madera, Taza de madera) |
| Resina | 3 | Se recolecta con Silvicultura · insumo de Manufactura (Plástico) |
| Leche | 3 | Se recolecta con Ganadería · insumo de Cocina (Café con leche) |
| Huevo | 1 | Se recolecta con Ganadería · insumo de Cocina (Huevo cocido) |
| Pescado | 4 | Se recolecta con Pesca · insumo de Cocina (Pescado a la plancha) |
| Marisco | 6 | Se recolecta con Pesca · insumo de Cocina (Caldo de marisco) |
| Lana | 3 | Se recolecta con Ganadería · insumo de Costura (Hilo de lana) |
| Fibra vegetal | 2 | Se recolecta con Silvicultura · insumo de Costura y Manufactura (Caña de pescar, Tela de fibra) |

## Intermedios

Bienes crafteados que a su vez son insumo de otra receta — no son un producto final.

| Ítem | Dc | Dónde participa |
|---|---:|---|
| Harina | 9 | Crafteo en Cocina (3 Trigo) · insumo de Cocina (Pan) |
| Plástico | 13 | Crafteo en Manufactura (3 Resina) · insumo de Manufactura (Plato de plástico, Taza de plástico) |
| Hilo de lana | 13 | Crafteo en Costura (3 Lana) · insumo de Costura (Chaleco de lana, Gorro de lana) |
| Tela de fibra | 9 | Crafteo en Costura (3 Fibra vegetal) · insumo de Costura (Camiseta de fibra, Pantalón de fibra) |

## Utensilios (contenedores)

Objetos durables de Carpintería y Manufactura. Cada uno porta contenido líquido o sólido, y por eso **no se apilan**: una taza vacía y una servida son objetos distintos.

| Ítem | Dc | Dónde participa |
|---|---:|---|
| Taza de madera | 5 | Crafteo en Carpintería (1 Madera) · contenedor de líquidos · familia "taza" · no apilable · insumo de Cocina (Café, Café con leche, Caldo de marisco, Jugo de manzana) |
| Taza de piedra | 4 | Crafteo en Carpintería (1 Piedra) · contenedor de líquidos · familia "taza" · no apilable · insumo de Cocina (Café, Café con leche, Caldo de marisco, Jugo de manzana) |
| Taza de plástico | 18 | Crafteo en Manufactura (1 Plástico) · contenedor de líquidos · familia "taza" · no apilable · insumo de Cocina (Café, Café con leche, Caldo de marisco, Jugo de manzana) |
| Plato de madera | 5 | Crafteo en Carpintería (1 Madera) · contenedor de sólidos · familia "plato" · no apilable · insumo de Cocina (Huevo cocido, Pescado a la plancha) |
| Plato de piedra | 4 | Crafteo en Carpintería (1 Piedra) · contenedor de sólidos · familia "plato" · no apilable · insumo de Cocina (Huevo cocido, Pescado a la plancha) |
| Plato de plástico | 18 | Crafteo en Manufactura (1 Plástico) · contenedor de sólidos · familia "plato" · no apilable · insumo de Cocina (Huevo cocido, Pescado a la plancha) |

## Consumibles (Cocina)

Ninguno existe suelto en el inventario: se sirven dentro de una instancia de utensilio, que queda ocupada hasta consumirlos.

| Ítem | Dc | Dónde participa |
|---|---:|---|
| Pan | 25 | Crafteo en Cocina (2 Harina) · se come en la mano, sin utensilio · efecto instantáneo: restaura 20 de energía |
| Café | 11 | Crafteo en Cocina (2 Granos de café + 1 Taza de cualquier material, **la Taza no se consume**) · líquido · buff temporal: +10% velocidad de Manufactura, 5 min |
| Jugo de manzana | 9 | Crafteo en Cocina (2 Manzana + 1 Taza de cualquier material, **la Taza no se consume**) · líquido · efecto instantáneo: restaura 15 de energía |
| Café con leche | 15 | Crafteo en Cocina (2 Granos de café + 1 Leche + 1 Taza de cualquier material, **la Taza no se consume**) · líquido · buff temporal: +15% velocidad de Manufactura, 6 min |
| Huevo cocido | 5 | Crafteo en Cocina (2 Huevo + 1 Plato de cualquier material, **el Plato no se consume**) · sólido · efecto instantáneo: restaura 18 de energía |
| Pescado a la plancha | 11 | Crafteo en Cocina (2 Pescado + 1 Plato de cualquier material, **el Plato no se consume**) · sólido · efecto instantáneo: restaura 25 de energía |
| Caldo de marisco | 17 | Crafteo en Cocina (2 Marisco + 1 Taza de cualquier material, **la Taza no se consume**) · líquido · buff temporal: +12% velocidad de Minería, 5 min |

## Equipables (herramientas y ropa)

Las herramientas dan un bono de velocidad; las prendas de Costura son cosmético puro y solo cambian una capa del avatar.

| Ítem | Dc | Dónde participa |
|---|---:|---|
| Pala de hierro | 27 | Crafteo en Manufactura (2 Mineral de hierro + 1 Madera) · slot herramienta_mano · +15% velocidad de Agricultura |
| Pico de minería | 27 | Crafteo en Manufactura (2 Mineral de hierro + 1 Madera) · slot herramienta_mano · +15% velocidad de Minería |
| Caña de pescar | 15 | Crafteo en Manufactura (2 Madera + 1 Fibra vegetal) · slot herramienta_mano · +15% velocidad de Pesca |
| Gorro de lana | 56 | Crafteo en Costura (2 Hilo de lana) · slot tocado · cosmético de avatar, sin bono |
| Chaleco de lana | 87 | Crafteo en Costura (3 Hilo de lana) · slot torso · cosmético de avatar, sin bono |
| Camiseta de fibra | 39 | Crafteo en Costura (2 Tela de fibra) · slot torso · cosmético de avatar, sin bono |
| Pantalón de fibra | 60 | Crafteo en Costura (3 Tela de fibra) · slot piernas · cosmético de avatar, sin bono |

## Decorativos (Carpintería)

| Ítem | Dc | Dónde participa |
|---|---:|---|
| Silla de madera | 13 | Crafteo en Carpintería (2 Madera) · se coloca en la grilla de la sala (1×1) |
| Mesa de madera | 17 | Crafteo en Carpintería (4 Madera) · se coloca en la grilla de la sala (2×1) |
| Estantería | 17 | Crafteo en Carpintería (3 Madera + 2 Piedra) · se coloca en la grilla de la sala (2×1) |

---

**Sobre los contenedores.** Un consumible líquido o sólido no existe suelto: craftear un Café ocupa una instancia concreta de taza, que queda servida hasta que alguien la bebe y entonces vuelve a estar vacía. El diccionario solo declara que la Taza *puede* contener un líquido (`contenedor.tipo: "liquido"`) y que Café y Jugo de manzana *requieren* ese contenedor (`es_liquido: true`); qué contiene una taza concreta es dato de la instancia, no del catálogo. La consecuencia de diseño es la que importa: llevar veinte cafés encima exige tener veinte tazas, así que Cocina depende de verdad de Carpintería y Manufactura en vez de necesitarlas una sola vez.

**Sobre las familias.** Para no triplicar cada receta por cada material de utensilio, un insumo puede pedir una `familia` ("cualquier taza", "cualquier plato") en vez de un `id` exacto. Las 3 tazas comparten familia `"taza"`; los 3 platos comparten `"plato"`.

**Cobertura del loop.** No queda ninguna materia prima ni intermedio sin una receta que lo consuma. Las nueve habilidades del GDD §3 tienen contenido: las cinco de recolección (Agricultura, Pesca, Minería, Silvicultura, Ganadería) producen materia prima, y las cuatro de producción (Cocina, Carpintería, Manufactura, Costura) la transforman. Ninguna se autoabastece — Costura necesita Lana de Ganadería y Fibra vegetal de Silvicultura; Cocina necesita a un pescador, un granjero o un ganadero *y* a un carpintero o un manufacturero por el utensilio.

**Sobre el plástico.** Con los precios derivados de la regla, la Resina (3 Dc) es la materia prima más cara de las tres de utensilios, así que el Plástico y sus tazas y platos son ahora los más caros — al revés de la v0.2, donde el material más caro producía el objeto más barato. El eje que diferencia madera, piedra y plástico sigue siendo solo el precio; si en algún momento se quiere que los tres coexistan por otra razón (peso, capacidad, durabilidad), esa diferencia hay que agregarla a mano.
