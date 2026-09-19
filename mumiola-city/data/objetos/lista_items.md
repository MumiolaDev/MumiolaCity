# Lista de items

> **Generado** desde `items.json` con `herramientas/generar_items.py` y
> `herramientas/generar_lista.py`. No editar a mano: los cambios se hacen en el generador,
> que ademas valida que los modelos existan y que los margenes cierren.

Catalogo v0.5 — 52 items, 26 con receta, 25 comprables al NPC.

El NPC **paga 60%** del valor base y **cobra 100%**. Siempre paga menos de lo que
cobra: es un piso de emergencia, no un negocio.

## Habilidades

| id | Nombre | Animacion |
|---|---|---|
| `agricultura` | Agricultura | `cavar` |
| `cocina` | Cocina | `trabajar` |
| `carpinteria` | Carpinteria | `martillar` |

## Estaciones

| id | Nombre | Modelo | Habilidad |
|---|---|---|---|
| `parcela` | Parcela | `prototipo/Floor_Dirt` | agricultura |
| `estufa` | Estufa | `restoran/stove_single` | cocina |
| `fregadero` | Fregadero | `restoran/kitchencounter_sink` | cocina |
| `banco_carpintero` | Banco de carpintero | `restoran/kitchentable_A` | carpinteria |

## Materia prima

| id | Nombre | Valor | NPC paga | NPC cobra | Modelo |
|---|---|---:|---:|---:|---|
| `semilla_tomate` | Semilla de tomate | 2 | 1 | 2 | — |
| `semilla_lechuga` | Semilla de lechuga | 2 | 1 | 2 | — |
| `semilla_papa` | Semilla de papa | 3 | 2 | 3 | — |
| `semilla_cebolla` | Semilla de cebolla | 3 | 2 | 3 | — |
| `semilla_zanahoria` | Semilla de zanahoria | 4 | 2 | 4 | — |
| `tomate` | Tomate | 7 | 4 | — | `restoran/food_ingredient_tomato` |
| `lechuga` | Lechuga | 7 | 4 | — | `restoran/food_ingredient_lettuce` |
| `papa` | Papa | 10 | 6 | — | `restoran/food_ingredient_potato` |
| `cebolla` | Cebolla | 10 | 6 | — | `restoran/food_ingredient_onion` |
| `tabla_madera` | Tabla de madera | 10 | 6 | 10 | `prototipo/Primitive_Beam` |
| `zanahoria` | Zanahoria | 12 | 7 | — | `restoran/food_ingredient_carrot` |

## Intermedios

| id | Nombre | Valor | NPC paga | NPC cobra | Modelo |
|---|---|---:|---:|---:|---|
| `carne_quemada` | Carne quemada | 0 | — | — | `restoran/food_ingredient_burger_trash` |
| `pan_hamburguesa` | Pan de hamburguesa | 5 | 3 | 5 | `restoran/food_ingredient_bun` |
| `queso` | Queso | 9 | 5 | 9 | `restoran/food_ingredient_cheese` |
| `tomate_rodajas` | Tomate en rodajas | 11 | 7 | — | `restoran/food_ingredient_tomato_slices` |
| `lechuga_picada` | Lechuga picada | 11 | 7 | — | `restoran/food_ingredient_lettuce_chopped` |
| `carne_cruda` | Carne cruda | 14 | 8 | 14 | `restoran/food_ingredient_burger_uncooked` |
| `cebolla_aros` | Cebolla en aros | 15 | 9 | — | `restoran/food_ingredient_onion_rings` |
| `jamon` | Jamon | 18 | 11 | 18 | `restoran/food_ingredient_ham` |
| `zanahoria_trozos` | Zanahoria en trozos | 18 | 11 | — | `restoran/food_ingredient_carrot_pieces` |
| `queso_fetas` | Queso en fetas | 20 | 12 | — | `restoran/food_ingredient_cheese_slice` |
| `papa_pure` | Pure de papa | 26 | 16 | — | `restoran/food_ingredient_potato_mashed` |
| `carne_cocida` | Carne cocida | 32 | 19 | — | `restoran/food_ingredient_burger_cooked` |
| `jamon_cocido` | Jamon cocido | 40 | 24 | — | `restoran/food_ingredient_ham_cooked` |

## Platos terminados

| id | Nombre | Valor | NPC paga | NPC cobra | Modelo |
|---|---|---:|---:|---:|---|
| `hamburguesa` | Hamburguesa | 78 | 47 | — | `restoran/food_burger` |
| `hamburguesa_veggie` | Hamburguesa vegetariana | 86 | 52 | — | `restoran/food_vegetableburger` |
| `guiso` | Guiso | 140 | 84 | — | `restoran/food_stew` |
| `plato_del_dia` | Plato del dia | 260 | 156 | — | `restoran/food_dinner` |

## Utensilios y vajilla

| id | Nombre | Valor | NPC paga | NPC cobra | Modelo |
|---|---|---:|---:|---:|---|
| `plato_sucio` | Plato sucio | 0 | — | — | `restoran/plate_dirty` |
| `bol_sucio` | Bol sucio | 0 | — | — | `restoran/bowl_dirty` |
| `plato` | Plato | 12 | 7 | 12 | `restoran/plate` |
| `bol` | Bol | 14 | 8 | 14 | `restoran/bowl` |
| `tabla_cortar` | Tabla de cortar | 25 | 15 | 25 | `restoran/cuttingboard` |
| `cuchillo` | Cuchillo | 30 | 18 | 30 | `restoran/knife` |
| `sarten` | Sarten | 40 | 24 | 40 | `restoran/pan_A` |
| `martillo` | Martillo | 40 | 24 | 40 | — |
| `serrucho` | Serrucho | 45 | 27 | 45 | — |
| `olla` | Olla | 55 | 33 | 55 | `restoran/pot_A` |

## Muebles y decoracion

| id | Nombre | Valor | NPC paga | NPC cobra | Modelo |
|---|---|---:|---:|---:|---|
| `frasco` | Frasco | 18 | 11 | 18 | `restoran/jar_A_medium` |
| `libro` | Libro | 22 | 13 | 22 | `muebles/book_single` |
| `banqueta` | Banqueta | 28 | 17 | — | `muebles/chair_stool_wood` |
| `maceta` | Maceta con cactus | 34 | 20 | 34 | `muebles/cactus_small_A` |
| `cajon_verduras` | Cajon de verduras | 40 | 24 | 40 | `restoran/crate_tomatoes` |
| `silla_madera` | Silla de madera | 45 | 27 | — | `muebles/chair_A_wood` |
| `alfombra` | Alfombra | 48 | 29 | 48 | `muebles/rug_rectangle_A` |
| `cuadro` | Cuadro | 50 | 30 | 50 | `muebles/pictureframe_medium` |
| `mesa_chica` | Mesa chica | 60 | 36 | — | `muebles/table_small` |
| `lampara_mesa` | Lampara de mesa | 62 | 37 | 62 | `muebles/lamp_table` |
| `estante` | Estante | 75 | 45 | — | `muebles/shelf_A_small` |
| `mesa` | Mesa | 90 | 54 | — | `muebles/table_medium` |
| `alacena` | Alacena | 120 | 72 | — | `muebles/cabinet_small` |
| `cama` | Cama | 150 | 90 | — | `muebles/bed_single_A` |

## Recetas

| Resultado | Insumos | Utensilios | Estacion | Habilidad | Nivel | Seg | XP | Si falla |
|---|---|---|---|---|---:|---:|---:|---|
| `tomate` | 1× semilla_tomate | — | parcela | agricultura | 1 | 120 | 6 | — |
| `lechuga` | 1× semilla_lechuga | — | parcela | agricultura | 1 | 120 | 6 | — |
| `papa` | 1× semilla_papa | — | parcela | agricultura | 2 | 180 | 9 | — |
| `cebolla` | 1× semilla_cebolla | — | parcela | agricultura | 2 | 180 | 9 | — |
| `zanahoria` | 1× semilla_zanahoria | — | parcela | agricultura | 3 | 240 | 12 | — |
| `tomate_rodajas` | 1× tomate | cuchillo, tabla_cortar | — | cocina | 1 | 3 | 4 | — |
| `lechuga_picada` | 1× lechuga | cuchillo, tabla_cortar | — | cocina | 1 | 3 | 4 | — |
| `queso_fetas` | 1× queso | cuchillo, tabla_cortar | — | cocina | 1 | 3 | 4 | — |
| `cebolla_aros` | 1× cebolla | cuchillo, tabla_cortar | — | cocina | 2 | 4 | 6 | — |
| `zanahoria_trozos` | 1× zanahoria | cuchillo, tabla_cortar | — | cocina | 2 | 4 | 6 | — |
| `papa_pure` | 2× papa | olla | estufa | cocina | 3 | 8 | 10 | — |
| `carne_cocida` | 1× carne_cruda | sarten | estufa | cocina | 2 | 6 | 8 | carne_quemada |
| `jamon_cocido` | 1× jamon | sarten | estufa | cocina | 3 | 6 | 10 | carne_quemada |
| `hamburguesa` | 1× pan_hamburguesa + 1× carne_cocida + 1× tomate_rodajas + 1× lechuga_picada | plato | — | cocina | 4 | 10 | 20 | — |
| `hamburguesa_veggie` | 1× pan_hamburguesa + 1× papa_pure + 1× tomate_rodajas + 1× lechuga_picada + 1× queso_fetas | plato | — | cocina | 4 | 12 | 24 | — |
| `guiso` | 1× papa_pure + 1× zanahoria_trozos + 1× cebolla_aros + 1× jamon_cocido | olla, bol | estufa | cocina | 6 | 20 | 40 | — |
| `plato_del_dia` | 1× hamburguesa + 1× guiso | plato | — | cocina | 8 | 15 | 70 | — |
| `plato` | 1× plato_sucio | — | fregadero | cocina | 1 | 4 | 1 | — |
| `bol` | 1× bol_sucio | — | fregadero | cocina | 1 | 4 | 1 | — |
| `banqueta` | 2× tabla_madera | serrucho, martillo | banco_carpintero | carpinteria | 1 | 5 | 8 | — |
| `silla_madera` | 3× tabla_madera | serrucho, martillo | banco_carpintero | carpinteria | 1 | 6 | 10 | — |
| `mesa_chica` | 4× tabla_madera | serrucho, martillo | banco_carpintero | carpinteria | 2 | 8 | 14 | — |
| `estante` | 5× tabla_madera | serrucho, martillo | banco_carpintero | carpinteria | 3 | 10 | 18 | — |
| `mesa` | 6× tabla_madera | serrucho, martillo | banco_carpintero | carpinteria | 3 | 12 | 22 | — |
| `alacena` | 8× tabla_madera | serrucho, martillo | banco_carpintero | carpinteria | 4 | 15 | 30 | — |
| `cama` | 10× tabla_madera | serrucho, martillo | banco_carpintero | carpinteria | 5 | 20 | 40 | — |

## Reglas que el generador verifica

- Todo modelo citado existe en `arte/modelos_3d/`.
- Todo insumo, utensilio, estacion, habilidad y resultado de fallo existe.
- Ningun ciclo de recetas.
- Todo item se consigue de alguna forma: o se craftea, o se compra.
- **Cadena productiva**: transformar deja ganancia, o nadie produce.
- **Muebles**: venderlos al NPC da perdida, o craftear y revender imprimiria
  dinero y dejarian de ser el sumidero de la economia.
- **Vajilla**: lavar recicla, no produce valor; queda fuera de la regla.
