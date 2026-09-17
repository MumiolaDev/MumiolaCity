extends Node3D

## Enciende una sala a la vez y muda al personaje entre ellas.
##
## Es provisional a proposito. En el paso 9 esta logica pasa a GameManager, y en
## el paso 6 una puerta interactuable reemplaza la tecla. Lo reutilizable ya vive
## en RoomController —activar(), desactivar(), rotar()—: lo unico desechable que
## hay aca es el disparador.
##
## Teclas: TAB cambia de sala, Q y E giran el encuadre un cuarto de vuelta.

## El personaje vive fuera de las salas porque su estado —inventario,
## habilidades, nivel— no es de ninguna sala en particular, y reparentar un
## CharacterBody3D entre escenas es fragil sin ninguna ganancia.
@export var personaje : PersonajeControlador

@onready var contenedor_salas : Node3D = $Salas

var _actual : int = -1


func _ready() -> void:
	if personaje == null:
		push_error("Mundo: falta asignar 'personaje' en el inspector.")
		return
	if salas().is_empty():
		push_error("Mundo: no hay ninguna RoomController colgando de Salas.")
		return
	ir_a_sala(0)


## Devuelve las salas del mundo, en el orden en que cuelgan del contenedor.
##
## Se leen del arbol en vez de mantener una lista exportada para que agregar una
## sala sea arrastrarla adentro de Salas y nada mas.
func salas() -> Array[RoomController]:
	var lista : Array[RoomController] = []
	for hijo in contenedor_salas.get_children():
		if hijo is RoomController:
			lista.append(hijo)
	return lista


## Devuelve la sala que se esta jugando, o null si todavia no hay ninguna.
func sala_actual() -> RoomController:
	var lista := salas()
	if _actual < 0 or _actual >= lista.size():
		return null
	return lista[_actual]


## Apaga todas las salas, enciende la del indice y muda al personaje.
##
## Apaga todo antes de encender una, y no la anterior antes de la nueva, porque
## con una sola camara por viewport dos salas encendidas a la vez dejan el
## resultado a merced del orden de los nodos.
func ir_a_sala(indice : int) -> bool:
	var lista := salas()
	if indice < 0 or indice >= lista.size() or indice == _actual:
		return false

	for sala in lista:
		sala.desactivar()

	var destino := lista[indice]
	destino.activar()
	personaje.entrar_en(destino)
	_actual = indice
	return true


## Pasa a la sala siguiente, dando la vuelta al llegar al final.
func siguiente_sala() -> void:
	var total := salas().size()
	if total > 0:
		ir_a_sala((_actual + 1) % total)


func _unhandled_input(evento : InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return

	if evento.keycode == KEY_TAB:
		siguiente_sala()
		return

	var sala := sala_actual()
	if sala == null:
		return
	if evento.keycode == KEY_Q:
		sala.rotar(-1)
	elif evento.keycode == KEY_E:
		sala.rotar(1)
