@tool
class_name ItemDefinition
extends Resource

## El esquema de un item: correspondencia directa con una entrada de items.json.
##
## Es @tool por una sola razon: cuando el editor carga un .tres cuyo script no lo
## es, entrega una *instancia placeholder* — se le pueden leer las propiedades
## pero no llamarle metodos, y el intento falla con "Attempt to call a method on
## a placeholder instance". herramientas/GenerarIconos.gd corre dentro del editor
## y necesita instanciar_visual(), asi que sin esto no puede.
##
## Es seguro porque esta clase es datos puros: no tiene _init con efectos, ni
## _ready, ni proceso. Marcarla no hace que corra nada en el editor; solo permite
## que sus metodos existan ahi.
##
## Nunca se muta en runtime. Una misma ItemDefinition la comparten todas las
## unidades de ese item que existan en el mundo, asi que escribirle encima le
## cambiaria el precio a todas las sillas del juego a la vez. Lo que varia por
## unidad vive en ItemInstance (D3).
##
## Cuatro campos que el plan original preveia no estan, y no es que falten:
## el catalogo v0.5 los volvio innecesarios.
##
##  - plantable : PlantableData — plantar es una receta cuya estacion es la
##    parcela, asi que no hace falta un tipo aparte.
##  - contenedor : ContenedorData — servir y vaciar son verbos, asi que el tipo
##    y la capacidad viven en el ContenedorBehavior del item.
##  - efecto / bono : Modificador — no hay buffs ni energia en el MVP.
##
## Si alguno vuelve, vuelve con su clase. Lo que si esta es todo lo que el
## catalogo usa hoy.

## Nombre del hijo que trae la malla en las escenas de objeto. Lo garantizan las
## 45 escenas generadas y tambien las hechas a mano.
const NODO_VISUAL := ^"Visual"

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

@export_group("Comercio")
## Si el NPC de abastecimiento lo vende.
##
## Por ahora todo lo que no se craftea se compra. A medida que una cadena se
## complete, alcanza con poner esto en false: el item deja de aparecer en la
## tienda sin tocar una linea de codigo.
@export var comprable : bool = true
## Si el NPC lo compra. False en lo que no vale nada: la carne quemada, la
## vajilla sucia.
@export var vendible : bool = true

@export_group("Comportamiento")
## Agrupa items intercambiables como insumo: "cualquier taza" (&"taza").
@export var familia : StringName = &""
@export var slot_equipo : StringName = &""
## Los verbos que ofrece este item. Son recursos compartidos y sin estado: las
## cincuenta sillas de una sala apuntan al mismo SentarseBehavior.
@export var interacciones : Array[InteractionBehavior] = []

@export_group("Produccion")
## Como se produce, o null si solo se compra.
##
## No guarda su resultado: el resultado es este mismo ItemDefinition. Guardarlo
## en los dos lados seria tener dos fuentes para un solo dato.
@export var receta : RecipeDefinition

@export_group("Colocacion")
## Si se puede dejar en el mundo. Una semilla no; un tomate si.
@export var colocable : bool = true
## Huella en celdas. Una mesa de 2x2 ocupa cuatro y las libera todas juntas.
@export var tamano_grilla : Vector2i = Vector2i.ONE
@export var rotable : bool = false

@export_group("Arte")
## Icono para la paleta y el inventario. Lo genera herramientas/GenerarIconos.gd
## y lo asigna el importador si el archivo existe.
@export var icono : Texture2D
## Escena propia del objeto. Si es null se usa el WorldObject generico.
@export var escena_mundo : PackedScene


## Devuelve si el item se agrupa en pilas en el inventario.
##
## No alcanza con el flag: un stack_maximo de 1 es un item unico aunque alguien
## haya dejado apilable en true por descuido.
func es_apilable() -> bool:
	return apilable and stack_maximo > 1


## Devuelve si el item se produce en vez de solo comprarse.
func se_craftea() -> bool:
	return receta != null


## Devuelve si cada unidad de este item puede tener estado propio y por lo tanto
## necesita su propia ItemInstance en el inventario (D1).
##
## Hoy la unica fuente de estado por unidad es contener algo, y un contenedor
## nunca es apilable, asi que las dos condiciones coinciden. Si alguna vez
## divergen —un item apilable que igual guarde estado— este es el lugar donde
## arreglarlo, y no cada sitio que hoy pregunta por apilable.
func tiene_estado_propio() -> bool:
	return not es_apilable()


## Devuelve una copia suelta de la malla de este item, o null si no tiene.
##
## Saca el hijo visual sin despertar al WorldObject. La raiz de una escena de
## objeto es un Area3D con WorldObject.gd, que en _ready() se conecta a
## input_event y exige una instancia no nula: instanciarla entera dejaria un
## objeto de mundo a medias, clickeable y quejandose por consola. Como
## instantiate() no corre _ready() hasta que el nodo entra al arbol, alcanza con
## sacarle el hijo y liberar el resto sin haberlo agregado nunca.
##
## Vive aca y no en quien la usa porque ya son dos —la vista previa del editor y
## el generador de iconos— y con dos copias de la misma astucia, el dia que una
## escena cambie de forma se arregla una sola.
##
## Quien la pide es dueno del nodo devuelto y tiene que liberarlo.
func instanciar_visual() -> Node3D:
	if escena_mundo == null:
		return null

	var raiz := escena_mundo.instantiate()
	var visual := raiz.get_node_or_null(NODO_VISUAL) as Node3D
	if visual != null:
		raiz.remove_child(visual)
	else:
		push_warning(
			"ItemDefinition %s: la escena %s no tiene un hijo '%s'."
			% [id, escena_mundo.resource_path, NODO_VISUAL]
		)
	raiz.free()
	return visual


## Devuelve si el item ofrece un verbo determinado.
func tiene_interaccion(verbo : StringName) -> bool:
	for comportamiento in interacciones:
		if comportamiento != null and comportamiento.verbo == verbo:
			return true
	return false
