class_name SaveGame
extends Resource

## El estado de una partida, tipado en memoria y diccionario en disco.
##
## Existe como clase y no como Dictionary suelto para que quien lo llene y quien
## lo lea trabajen contra campos con nombre y tipo. La conversion a diccionario
## ocurre solo al borde, en SaveManager.
##
## Lo que deliberadamente no esta: quien esta sentado, los buffs activos, y en
## general todo lo que vive en WorldObject.estado_runtime. Es estado de sesion y
## no tiene sentido que siga siendo cierto manana (D3).

## Sube cuando cambia el esquema. Cuesta una linea hoy y es la diferencia entre
## poder migrar los guardados y tener que borrarlos, lo cual va a pasar: hay
## siete decisiones de arquitectura todavia abiertas.
@export var version_formato : int = 1
@export var timestamp_guardado : int = 0

## Ruta al .tscn de la sala donde estaba el jugador.
##
## La ruta y no el indice: el orden de los nodos cambia al agregar una sala, y un
## guardado no puede depender de eso.
@export var sala_actual : String = ""
## En que celda estaba parado, no en que posicion de mundo. La celda es el dato
## real; la posicion es su consecuencia y depende de altura_piso y del cell_size.
@export var celda_jugador : Vector2i = Vector2i.ZERO

## Ruta de sala -> lo que to_dict() de esa sala devolvio.
@export var salas : Dictionary = {}

## Lo que el jugador lleva encima, tal como lo devuelve InventoryManager.
@export var inventario : Dictionary = {}


## Vuelca el estado a un diccionario listo para serializar.
##
## Los Vector2i salen como arrays de dos enteros porque JSON no tiene vectores.
func to_dict() -> Dictionary:
	return {
		"version_formato": version_formato,
		"timestamp_guardado": timestamp_guardado,
		"sala_actual": sala_actual,
		"celda_jugador": [celda_jugador.x, celda_jugador.y],
		"salas": salas,
		"inventario": inventario,
	}


## Rellena el estado desde un diccionario leido de disco.
##
## Todo numero que viene de JSON llega como float, incluso los que se escribieron
## como enteros: el formato no distingue. De ahi los int() en cada lectura, sin
## los cuales una celda seria Vector2i(3.0, 4.0) y fallaria el tipado.
func from_dict(d : Dictionary) -> void:
	version_formato = int(d.get("version_formato", 1))
	timestamp_guardado = int(d.get("timestamp_guardado", 0))
	sala_actual = str(d.get("sala_actual", ""))

	var celda : Array = d.get("celda_jugador", [0, 0])
	if celda.size() == 2:
		celda_jugador = Vector2i(int(celda[0]), int(celda[1]))

	salas = d.get("salas", {})
	inventario = d.get("inventario", {})
