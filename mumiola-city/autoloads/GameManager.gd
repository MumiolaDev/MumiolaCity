extends Node

## Sabe que sala se esta jugando y quien es el jugador. Es el punto al que el
## resto del juego le pregunta "donde estamos" sin tener que conocer el arbol.
##
## No usa change_scene_to_packed() para cambiar de sala, aunque el plan original
## lo proponia: eso reemplaza el arbol entero, jugador incluido, y obligaria a
## reconstruirlo y reubicarlo en cada puerta. Las salas conviven en un contenedor
## y se encienden de a una, que ademas deja volver a la anterior sin recargarla.
##
## Un autoload sobrevive a los cambios de escena, asi que todo lo que guarda son
## referencias que pueden quedar colgando. Por eso registrar_contenedor() limpia
## el estado y todo acceso comprueba is_instance_valid(): una referencia muerta
## aca no da error, devuelve basura.

## Se emite al terminar de cambiar de sala, con la sala ya encendida y el
## jugador ya adentro.
signal sala_cambiada(sala : RoomController)
## Se emite cuando un jugador se registra, para lo que necesite engancharse a el.
signal jugador_registrado(jugador : PersonajeControlador)

## Un aviso pasajero para el jugador. Quien lo emite no sabe ni le importa si hay
## alguien mostrandolo.
signal aviso(texto : String)
## Cambio el texto de ayuda fijo.
signal ayuda_cambiada(texto : String)

var _jugador : PersonajeControlador = null
var _contenedor : Node = null
var _sala_actual : RoomController = null
var _ayuda : String = ""


## El jugador se anota solo desde su _ready().
##
## Al reves —que el manager lo busque con get_node("/root/...")— ata el manager a
## la forma del arbol, que cambia cada vez que se reorganiza una escena.
func registrar_jugador(jugador : PersonajeControlador) -> void:
	_jugador = jugador
	jugador_registrado.emit(jugador)


## Declara de que nodo cuelgan las salas. Lo llama el mundo al arrancar.
##
## Limpia la sala actual porque un mundo nuevo trae salas nuevas: la anterior ya
## no existe aunque la referencia siga pareciendo valida.
func registrar_contenedor(nodo : Node) -> void:
	_contenedor = nodo
	_sala_actual = null


## Devuelve el jugador actual, o null si todavia no se registro ninguno.
func jugador_actual() -> PersonajeControlador:
	return _jugador if is_instance_valid(_jugador) else null


## Devuelve la sala que se esta jugando, o null.
func sala_actual() -> RoomController:
	return _sala_actual if is_instance_valid(_sala_actual) else null


## Devuelve las salas disponibles, en el orden en que cuelgan del contenedor.
func salas() -> Array[RoomController]:
	var lista : Array[RoomController] = []
	if not is_instance_valid(_contenedor):
		return lista
	for hijo in _contenedor.get_children():
		if hijo is RoomController:
			lista.append(hijo)
	return lista


## Enciende una sala y muda al jugador. Devuelve si el cambio ocurrio.
##
## Apaga todas antes de encender una, y no solo la anterior: con una sola camara
## por viewport, dos salas encendidas a la vez dejan el resultado a merced del
## orden de los nodos.
func ir_a_sala(sala : RoomController) -> bool:
	if not is_instance_valid(sala) or sala == sala_actual():
		return false

	for otra in salas():
		otra.desactivar()
	sala.activar()
	_sala_actual = sala

	var jugador := jugador_actual()
	if jugador != null:
		jugador.entrar_en(sala)

	sala_cambiada.emit(sala)
	return true


## Va a la sala que ocupa ese lugar en el contenedor.
func ir_a_indice(indice : int) -> bool:
	var lista := salas()
	if indice < 0 or indice >= lista.size():
		return false
	return ir_a_sala(lista[indice])


## Pasa a la sala siguiente, dando la vuelta al llegar al final.
func siguiente_sala() -> void:
	var lista := salas()
	if lista.is_empty():
		return
	var actual := lista.find(sala_actual())
	ir_a_sala(lista[(actual + 1) % lista.size()])


## Instancia una sala nueva en el contenedor y va a ella.
##
## Es el camino para las salas que no estan puestas de antemano: las viviendas
## de otros jugadores, que no tiene sentido tener todas cargadas.
func cargar_sala(escena : PackedScene) -> RoomController:
	if escena == null or not is_instance_valid(_contenedor):
		return null

	var nodo := escena.instantiate()
	if not (nodo is RoomController):
		push_error("GameManager: la escena %s no es una RoomController." % escena.resource_path)
		nodo.free()
		return null

	_contenedor.add_child(nodo)
	ir_a_sala(nodo)
	return nodo


## Avisa algo al jugador, si hay interfaz que lo muestre.
##
## Es un canal y no una llamada a la UI: quien avisa no tiene que saber si el HUD
## existe. Con una llamada directa, borrar el HUD rompe a quien lo llamaba, que
## es exactamente lo que la capa de interfaz promete que no pasa.
##
## Si algun dia este canal crece —niveles de aviso, cola, historial— se muda a su
## propio autoload. Por ahora son tres lineas y no justifican uno.
func avisar(texto : String) -> void:
	aviso.emit(texto)


## Avisa el mensaje que le corresponde a un codigo de rechazo. Un OK no avisa
## nada, porque no hay nada que explicar.
func avisar_error(codigo : Errores.Codigo) -> void:
	if not Errores.ok(codigo):
		aviso.emit(Errores.mensaje(codigo))


## Fija el texto de ayuda de la esquina.
func mostrar_ayuda(texto : String) -> void:
	_ayuda = texto
	ayuda_cambiada.emit(texto)


## Devuelve la ayuda vigente, para una interfaz que aparezca despues de fijada.
func ayuda() -> String:
	return _ayuda
