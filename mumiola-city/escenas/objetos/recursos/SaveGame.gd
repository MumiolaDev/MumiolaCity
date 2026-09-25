class_name SaveGame
extends Resource

## Un perfil: quien sos, que llevas encima y donde te quedaste. Tipado en
## memoria y diccionario en disco (o en la red).
##
## Existe como clase y no como Dictionary suelto para que quien lo llene y quien
## lo lea trabajen contra campos con nombre y tipo. La conversion a diccionario
## ocurre solo al borde: en SaveManager, que lo arma, y en ServidorLocal, que lo
## crea para un perfil nuevo.
##
## Desde la version 3 un perfil es el equivalente local de una cuenta: tiene id
## y nombre, y hay tantos como jugadores usen este equipo. Antes era una sola
## partida sin duenio, en user://partida.json.
##
## Las salas no estan: cada una se guarda sola, como documento, por Servidor. La
## partida es tu estado; una sala es de quien la tenga, y la visitan otros.
##
## Lo que deliberadamente no esta: quien esta sentado, los buffs activos, y en
## general todo lo que vive en WorldObject.estado_runtime. Es estado de sesion y
## no tiene sentido que siga siendo cierto manana (D3).

## Sube cuando cambia el esquema. Cuesta una linea hoy y es la diferencia entre
## poder migrar los guardados y tener que borrarlos.
@export var version_formato : int = 3
@export var timestamp_guardado : int = 0

## El id del perfil. Es tambien el id de actor del jugador y el duenio de sus
## salas: la misma identidad en todos lados.
@export var perfil_id : String = ""
## Como se llama, tal como lo ven los demas.
@export var nombre : String = ""
## Cuando se creo, en segundos Unix.
@export var creado : int = 0

## Id de la sala donde estaba el jugador.
##
## Hasta la version 1 era la ruta del .tscn de la sala. Dejo de servir cuando las
## salas pasaron a ser documentos que crea el jugador y que no tienen escena.
@export var sala_actual : String = ""
## En que celda estaba parado, no en que posicion de mundo. La celda es el dato
## real; la posicion es su consecuencia y depende de altura_piso y del cell_size.
@export var celda_jugador : Vector2i = Vector2i.ZERO

## Lo que el jugador lleva encima, tal como lo devuelve InventoryManager.
@export var inventario : Dictionary = {}

## La xp por habilidad. Solo la xp: el nivel se recalcula al cargar, porque
## guardar los dos seria tener dos fuentes para un solo hecho.
@export var habilidades : Dictionary = {}


## Vuelca el estado a un diccionario listo para serializar.
##
## Los Vector2i salen como arrays de dos enteros porque JSON no tiene vectores.
func to_dict() -> Dictionary:
	return {
		"version_formato": version_formato,
		"timestamp_guardado": timestamp_guardado,
		"perfil_id": perfil_id,
		"nombre": nombre,
		"creado": creado,
		"sala_actual": sala_actual,
		"celda_jugador": [celda_jugador.x, celda_jugador.y],
		"inventario": inventario,
		"habilidades": habilidades,
	}


## Rellena el estado desde un diccionario leido de disco.
##
## Todo numero que viene de JSON llega como float, incluso los que se escribieron
## como enteros: el formato no distingue. De ahi los int() en cada lectura, sin
## los cuales una celda seria Vector2i(3.0, 4.0) y fallaria el tipado.
func from_dict(d : Dictionary) -> void:
	version_formato = int(d.get("version_formato", 1))
	timestamp_guardado = int(d.get("timestamp_guardado", 0))
	perfil_id = str(d.get("perfil_id", ""))
	nombre = str(d.get("nombre", ""))
	creado = int(d.get("creado", 0))
	sala_actual = str(d.get("sala_actual", ""))

	var celda : Array = d.get("celda_jugador", [0, 0])
	if celda.size() == 2:
		celda_jugador = Vector2i(int(celda[0]), int(celda[1]))

	inventario = d.get("inventario", {})
	habilidades = d.get("habilidades", {})
