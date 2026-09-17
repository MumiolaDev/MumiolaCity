class_name ItemDefinition
extends Resource

## El esquema de un item: correspondencia directa con una entrada de items.json.
##
## Nunca se muta en runtime. Una misma ItemDefinition la comparten todas las
## unidades de ese item que existan en el mundo, asi que escribirle encima le
## cambiaria el precio a todas las sillas del juego a la vez. Lo que varia por
## unidad vive en ItemInstance (D3).
##
## Subconjunto de fase 1. La version completa (CLASES.md 1.1) declara ademas
## receta : RecipeDefinition, plantable : PlantableData, contenedor :
## ContenedorData y efecto / bono : Modificador. Esos cuatro tipos son de la
## fase 2 y todavia no existen, y GDScript no compila un script que nombre un
## tipo inexistente: los campos llegan con sus clases, no antes. No estan
## olvidados.

@export var id : StringName = &""
## Nombre de presentacion, con tildes y mayusculas. El id nunca las lleva (D4).
@export var nombre : String = ""
@export_multiline var descripcion : String = ""
@export_enum("materia_prima", "intermedio", "utensilio",
	"consumible", "equipable", "decorativo") var categoria : String = "decorativo"
## Solo para materia prima: que habilidad la produce. Vacio en todo lo crafteado,
## porque ahi la habilidad ya la dice la receta (D11).
@export var habilidad_origen : StringName = &""
@export var peso : float = 0.1
@export var apilable : bool = true
@export var stack_maximo : int = 99
## Referencia de precio para el mercado, no un precio: el precio lo hacen los
## jugadores.
@export var valor_base : int = 1

@export_group("Comportamiento")
## Agrupa items intercambiables como insumo: "cualquier taza" (&"taza").
@export var familia : StringName = &""
@export var slot_equipo : StringName = &""
## Los verbos que ofrece este item. Son recursos compartidos y sin estado: las
## cincuenta sillas de una sala apuntan al mismo SentarseBehavior.
@export var interacciones : Array[InteractionBehavior] = []

@export_group("Colocacion")
## Huella en celdas. Una mesa de 2x2 ocupa cuatro y las libera todas juntas.
@export var tamano_grilla : Vector2i = Vector2i.ONE
@export var rotable : bool = false

@export_group("Arte")
@export var icono : Texture2D
## Escena propia del objeto. Si es null se usa el WorldObject generico.
@export var escena_mundo : PackedScene


## Devuelve si el item se agrupa en pilas en el inventario.
##
## No alcanza con el flag: un stack_maximo de 1 es un item unico aunque alguien
## haya dejado apilable en true por descuido.
func es_apilable() -> bool:
	return apilable and stack_maximo > 1


## Devuelve si el item ofrece un verbo determinado.
func tiene_interaccion(verbo : StringName) -> bool:
	for comportamiento in interacciones:
		if comportamiento != null and comportamiento.verbo == verbo:
			return true
	return false
