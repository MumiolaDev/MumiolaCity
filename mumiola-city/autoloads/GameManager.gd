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

## Se paso de recorrer la sala a editarla, o al reves.
signal modo_cambiado(modo : Modo)


## En que esta el jugador: recorriendo la sala o construyendola.
##
## Vive aca y no en el editor porque varias cosas que no se conocen entre si
## necesitan leerlo: el personaje deja de caminar al clic, el menu contextual
## deja de abrirse, la vista previa aparece. Con el modo colgando del editor,
## todas ellas tendrian que conocer al editor.
enum Modo { JUGANDO, EDITANDO }

## Cuantos menus hay abiertos ahora mismo. Un contador y no un bool porque nada
## impide que algun dia haya dos.
var _menus_abiertos : int = 0

var _jugador : PersonajeControlador = null
var _contenedor : Node = null
var _sala_actual : RoomController = null
var _ayuda : String = ""
var _modo : Modo = Modo.JUGANDO


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


## Devuelve en que modo esta el juego.
## Avisa que un menu se abrio o se cerro.
##
## Pasa por aca y no del menu al personaje directamente por la regla de
## direccion: la UI conoce a los managers, el mundo lee un dato, y ninguno de
## los dos sabe que existe el otro.
func avisar_menu(abierto : bool) -> void:
	_menus_abiertos = maxi(0, _menus_abiertos + (1 if abierto else -1))


## Devuelve si hay algun menu abierto ahora mismo.
##
## Sirve para que el clic que cancela un menu no cuente ademas como una orden al
## mundo: cerrar un menu y mandar al personaje a caminar son dos intenciones
## distintas, y el mismo clic no puede ser las dos.
##
## Se pregunta por el estado y no por un aviso al cerrarse, que fue el primer
## intento y estaba tarde: el orden real es que _unhandled_input ve el clic
## **antes** de que el popup emita popup_hide. Cuando el mundo mira, el menu
## todavia esta abierto — y eso es justamente lo que hay que mirar.
func hay_menu_abierto() -> bool:
	return _menus_abiertos > 0


func modo() -> Modo:
	return _modo


## Devuelve si se esta editando la sala.
##
## Existe ademas de modo() porque "if GameManager.editando():" se lee mucho mejor
## que comparar contra el enum en los quince lugares que van a preguntarlo.
func editando() -> bool:
	return _modo == Modo.EDITANDO


## Cambia de modo y avisa. Devuelve si hubo cambio.
##
## Al salir del modo editor se olvida el historial de la sala: deshacer despues
## de haberse ido a recorrerla desharia cosas que el jugador ya dio por hechas.
func cambiar_modo(nuevo : Modo) -> bool:
	if nuevo == _modo:
		return false

	_modo = nuevo
	if _modo == Modo.JUGANDO:
		var sala := sala_actual()
		if sala != null:
			sala.olvidar_historial()

	modo_cambiado.emit(_modo)
	return true


## Alterna entre recorrer y editar.
func alternar_modo() -> void:
	cambiar_modo(Modo.JUGANDO if editando() else Modo.EDITANDO)
