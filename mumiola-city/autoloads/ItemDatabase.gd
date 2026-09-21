extends Node

## Indice en memoria de todas las ItemDefinition del juego (D10).
##
## Godot no autocarga los .tres de una carpeta: hay que recorrerla a mano. Este
## autoload lo hace una vez al arrancar y despues todo el juego resuelve por id,
## que es lo que permite que ItemInstance guarde definicion_id en vez de la
## referencia al recurso.
##
## Va primero en el orden de autoloads (D9) porque todos los demas leen
## definiciones.

const CARPETA := "res://data/objetos/definiciones"

var _por_id : Dictionary = {}          # StringName -> ItemDefinition
var _por_familia : Dictionary = {}     # StringName -> Array[ItemDefinition]
var _por_categoria : Dictionary = {}   # String     -> Array[ItemDefinition]


func _ready() -> void:
	recargar()


## Vuelve a escanear la carpeta de definiciones y reconstruye los tres indices.
func recargar() -> void:
	_por_id.clear()
	_por_familia.clear()
	_por_categoria.clear()

	var dir := DirAccess.open(CARPETA)
	if dir == null:
		push_error("ItemDatabase: no se pudo abrir %s." % CARPETA)
		return

	for archivo in dir.get_files():
		# En una build exportada los .tres llegan renombrados a .tres.remap. Sin
		# esto el catalogo queda vacio solo en el juego exportado, que es la
		# peor forma posible de descubrirlo.
		var nombre := archivo.trim_suffix(".remap")
		if not nombre.ends_with(".tres"):
			continue

		var recurso := ResourceLoader.load(CARPETA.path_join(nombre))
		if recurso is ItemDefinition:
			_registrar(recurso)
		else:
			push_warning("ItemDatabase: %s no es una ItemDefinition." % nombre)


## Devuelve la definicion de un id, o null si el catalogo no la tiene.
func obtener(id : StringName) -> ItemDefinition:
	return _por_id.get(id, null)


## Devuelve si el catalogo conoce ese id.
func existe(id : StringName) -> bool:
	return _por_id.has(id)


## Devuelve todos los items de una familia: "cualquier taza" para una receta.
func items_de_familia(familia : StringName) -> Array[ItemDefinition]:
	var salida : Array[ItemDefinition] = []
	salida.assign(_por_familia.get(familia, []))
	return salida


## Devuelve todos los items de una categoria.
func items_de_categoria(categoria : String) -> Array[ItemDefinition]:
	var salida : Array[ItemDefinition] = []
	salida.assign(_por_categoria.get(categoria, []))
	return salida


## Devuelve todos los items que se pueden dejar en una sala, ordenados por id.
##
## Se ordena para que la paleta del editor no cambie de orden entre arranques:
## el catalogo se arma recorriendo una carpeta y ese recorrido no promete nada.
func colocables() -> Array[ItemDefinition]:
	var ids : Array = _por_id.keys()
	ids.sort()

	var salida : Array[ItemDefinition] = []
	for id in ids:
		var def : ItemDefinition = _por_id[id]
		if def.colocable and def.escena_mundo != null:
			salida.append(def)
	return salida


## Cuantas definiciones tiene cargadas el catalogo.
func cantidad() -> int:
	return _por_id.size()


## Mete una definicion en los tres indices.
##
## Un id repetido es un error y no un aviso: quedarse con el ultimo que se cargo
## hace que el catalogo dependa del orden del sistema de archivos, y el bug
## aparece meses despues como "este item tiene el precio de otro".
func _registrar(def : ItemDefinition) -> void:
	if def.id == &"":
		push_error("ItemDatabase: hay una ItemDefinition sin id en %s." % def.resource_path)
		return
	if _por_id.has(def.id):
		push_error(
			"ItemDatabase: el id '%s' esta duplicado (%s y %s). Los ids son unicos en todo el catalogo."
			% [def.id, _por_id[def.id].resource_path, def.resource_path]
		)
		return

	_por_id[def.id] = def
	if def.familia != &"":
		_por_familia.get_or_add(def.familia, []).append(def)
	_por_categoria.get_or_add(def.categoria, []).append(def)
