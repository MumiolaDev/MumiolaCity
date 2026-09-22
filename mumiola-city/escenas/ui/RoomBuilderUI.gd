class_name RoomBuilderUI
extends Control

## La paleta del editor de sala: que mueble o que pieza se va a colocar.
##
## Emite lo que se eligio y no coloca nada. Quien coloca es EditorSala, y quien
## muta la sala es RoomController.aplicar() (D23). Si esta clase llamara a
## colocar_objeto() o a pintar(), volveria a haber varias formas de cambiar una
## sala y el dia del servidor habria que interceptarlas todas.
##
## Se puede borrar del arbol, como el HUD y el menu contextual: el editor
## comprueba que exista y sin ella simplemente no hay de donde elegir.
##
## A diferencia del HUD, esta si se come los clics de su rectangulo. El HUD va
## con mouse_filter en IGNORE porque flota sobre el mundo y no se toca; la
## paleta ocupa su lugar en pantalla y se clickea, asi que dejar pasar el clic
## haria que elegir una silla ademas mandara al personaje a caminar debajo.
##
## Dos senales y no una porque son dos cosas distintas de verdad: un mueble es un
## WorldObject con su ItemInstance, y una pieza es escenario pintado en un
## GridMap. El editor construye operaciones distintas con cada una.

## Se eligio un item colocable.
signal item_elegido(definicion : ItemDefinition)
## Se eligio una pieza de escenario de una capa.
signal pieza_elegida(capa : StringName, pieza : StringName)
## Se deselecciono todo.
signal seleccion_vaciada()

## Que clase de cosa hay elegida ahora.
enum Clase { NADA, ITEM, PIEZA }

## Las pestanias de items: categoria del catalogo -> nombre visible.
##
## El orden es el de la pestania, y arranca por muebles porque es lo que se usa
## el noventa por ciento del tiempo en un editor de salas. Una categoria sin
## items colocables no genera pestania, asi que agregar una al catalogo no
## obliga a tocar esto.
const CATEGORIAS := {
	"decorativo": "Muebles",
	"utensilio": "Utensilios",
	"intermedio": "Preparados",
	"consumible": "Comida",
	"materia_prima": "Ingredientes",
}

## Las pestanias de escenario: capa -> nombre visible.
const CAPAS := {
	CatalogoPiezas.SUELO: "Suelo",
	CatalogoPiezas.PAREDES: "Paredes",
}

## Cuanto mide el icono de cada entrada.
@export var size_icono : Vector2i = Vector2i(56, 56)
## Si la paleta se muestra sola al entrar en modo edicion y se esconde al salir.
@export var seguir_el_modo : bool = true

@onready var _pestanias : TabContainer = $Panel/Pestanias

var _listas : Array[ItemList] = []
var _clase : Clase = Clase.NADA
var _item : ItemDefinition = null
var _capa : StringName = &""
var _pieza : StringName = &""


func _ready() -> void:
	if _pestanias == null:
		push_error("RoomBuilderUI: falta el nodo Panel/Pestanias.")
		return

	refrescar()

	if seguir_el_modo:
		GameManager.modo_cambiado.connect(_al_cambiar_modo)
		_al_cambiar_modo(GameManager.modo())

	# La estructura se dibuja con la MeshLibrary de la sala activa, asi que al
	# cambiar de sala hay que rearmar esas pestanias.
	GameManager.sala_cambiada.connect(_al_cambiar_sala)


## Rearma la paleta entera desde el catalogo y desde la sala activa.
##
## Se puede llamar en cualquier momento: es lo que hay que hacer despues de
## regenerar los iconos o de agregar items, y no tiene efectos fuera de esta
## escena.
func refrescar() -> void:
	# remove_child antes de queue_free, y no solo queue_free: el nodo sigue
	# siendo hijo hasta el final del cuadro, asi que su nombre sigue ocupado y
	# Godot renombra al nuevo a "@ItemList@63". La pestania entonces se llama
	# asi, porque TabContainer usa el nombre del hijo como titulo.
	for hijo in _pestanias.get_children():
		_pestanias.remove_child(hijo)
		hijo.queue_free()
	_listas.clear()
	limpiar()

	for categoria in CATEGORIAS:
		var items := _colocables_de(categoria)
		if items.is_empty():
			continue
		var lista := _nueva_lista(CATEGORIAS[categoria])
		for def in items:
			var i := lista.add_item(def.nombre, def.icono)
			lista.set_item_metadata(i, def)
			lista.set_item_tooltip(i, _descripcion_de(def))

	for capa in CAPAS:
		var lista := _nueva_lista(CAPAS[capa])
		var biblioteca := _biblioteca_de(capa)
		for pieza in CatalogoPiezas.PIEZAS[capa]:
			var i := lista.add_item(_legible(pieza), _vista_previa(biblioteca, pieza))
			lista.set_item_metadata(i, {"capa": capa, "pieza": pieza})
			lista.set_item_tooltip(i, String(pieza))


## Devuelve que clase de cosa esta elegida.
func clase() -> Clase:
	return _clase


## El item elegido, o null si lo elegido no es un item.
func item() -> ItemDefinition:
	return _item if _clase == Clase.ITEM else null


## La capa de la pieza elegida, o vacio si lo elegido no es una pieza.
func capa() -> StringName:
	return _capa if _clase == Clase.PIEZA else &""


## La pieza elegida, o vacio si lo elegido no es una pieza.
func pieza() -> StringName:
	return _pieza if _clase == Clase.PIEZA else &""


## Olvida lo elegido y apaga la seleccion de todas las listas.
func limpiar() -> void:
	for lista in _listas:
		lista.deselect_all()
	if _clase == Clase.NADA:
		return
	_clase = Clase.NADA
	_item = null
	_capa = &""
	_pieza = &""
	seleccion_vaciada.emit()


## Crea una pestania con su lista en modo icono.
##
## ItemList ya resuelve la grilla, el scroll y la seleccion, asi que aca no hay
## una sola linea de disposicion propia.
func _nueva_lista(titulo : String) -> ItemList:
	var lista := ItemList.new()
	lista.name = titulo
	lista.icon_mode = ItemList.ICON_MODE_TOP
	lista.fixed_icon_size = size_icono
	lista.max_columns = 0
	lista.same_column_width = true
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.item_selected.connect(_al_elegir.bind(lista))
	_pestanias.add_child(lista)
	_listas.append(lista)
	return lista


## Atiende una seleccion y la convierte en la senal que corresponda.
##
## Apaga la seleccion de las demas listas primero: cada ItemList lleva la suya
## por separado, asi que sin esto quedarian varias cosas marcadas a la vez y la
## paleta mentiria sobre lo que se va a colocar.
func _al_elegir(indice : int, lista : ItemList) -> void:
	for otra in _listas:
		if otra != lista:
			otra.deselect_all()

	var dato : Variant = lista.get_item_metadata(indice)

	if dato is ItemDefinition:
		_clase = Clase.ITEM
		_item = dato
		_capa = &""
		_pieza = &""
		item_elegido.emit(_item)
		return

	if dato is Dictionary and dato.has("capa"):
		_clase = Clase.PIEZA
		_item = null
		_capa = dato["capa"]
		_pieza = dato["pieza"]
		pieza_elegida.emit(_capa, _pieza)
		return

	push_error("RoomBuilderUI: entrada sin metadato reconocible en '%s'." % lista.name)


## Los items colocables de una categoria, en el orden estable del catalogo.
func _colocables_de(categoria : String) -> Array[ItemDefinition]:
	var salida : Array[ItemDefinition] = []
	for def in ItemDatabase.colocables():
		if def.categoria == categoria:
			salida.append(def)
	return salida


## La MeshLibrary de una capa en la sala activa, o null si no hay sala.
##
## Sin sala la paleta se arma igual, solo que sin iconos de escenario: los
## nombres de las piezas los declara CatalogoPiezas y no dependen de que haya
## una sala cargada.
func _biblioteca_de(capa : StringName) -> MeshLibrary:
	var sala := GameManager.sala_actual()
	if sala == null or sala.grid == null:
		return null
	return sala.grid.biblioteca_de(capa)


## La miniatura que la propia MeshLibrary ya guarda de cada pieza.
func _vista_previa(biblioteca : MeshLibrary, pieza : StringName) -> Texture2D:
	if biblioteca == null:
		return null
	var id := CatalogoPiezas.id_de(biblioteca, pieza)
	return null if id == -1 else biblioteca.get_item_preview(id)


## Convierte un id de pieza en algo legible: "pared_doble_base" -> "Pared doble base".
func _legible(id : StringName) -> String:
	var texto := String(id).replace("_", " ")
	return texto.substr(0, 1).to_upper() + texto.substr(1)


## El texto que se ve al dejar el puntero encima.
func _descripcion_de(def : ItemDefinition) -> String:
	var huella := ""
	if def.tamano_grilla != Vector2i.ONE:
		huella = "   %dx%d celdas" % [def.tamano_grilla.x, def.tamano_grilla.y]
	return "%s%s\n%s" % [def.nombre, huella, def.descripcion]


func _al_cambiar_modo(modo : GameManager.Modo) -> void:
	visible = modo == GameManager.Modo.EDITANDO
	if not visible:
		limpiar()


func _al_cambiar_sala(_sala : RoomController) -> void:
	refrescar()
