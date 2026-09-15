class_name PersonajeControlador
extends CharacterBody3D

## Se emite al terminar un recorrido, con la celda en la que quedo el personaje.
signal llego_a_celda(celda : Vector2i)

## La grilla de la sala en la que esta parado el personaje.
@export var grid : IsoGrid
## La camara con la que se convierte un clic de pantalla en una celda.
@export var camara : Camera3D
## Metros por segundo. Con celdas de 1 metro, es tambien celdas por segundo.
@export var velocidad : float = 3.0

## idle | caminando | sentado | actuando
var estado : StringName = &"idle"

var _ruta : Array[Vector2i] = []

## El nodo que compone y orienta al avatar. Gira el, nunca el cuerpo.
@onready var avatar : AvatarComposer = $Visual


func _ready() -> void:
	avatar.reproducir(&"idle")


func _unhandled_input(evento : InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var celda := grid.celda_bajo_puntero(camara, evento.position)
		if celda != IsoGrid.SIN_CELDA:
			ir_a_celda(celda)


func _physics_process(delta : float) -> void:
	if _ruta.is_empty():
		velocity = Vector3.ZERO
		return

	var objetivo := grid.celda_a_mundo(_ruta[0])
	objetivo.y = global_position.y
	var hacia := objetivo - global_position
	var paso := velocidad * delta

	if hacia.length() <= paso:
		global_position = objetivo
		_ruta.remove_at(0)
		if _ruta.is_empty():
			velocity = Vector3.ZERO
			estado = &"idle"
			avatar.reproducir(&"idle")
			llego_a_celda.emit(grid.mundo_a_celda(global_position))
		return

	velocity = hacia.normalized() * velocidad
	_mirar_hacia(hacia)
	avatar.reproducir(&"caminar")
	move_and_slide()


## Calcula la ruta hasta una celda y empieza a recorrerla. Llamarla mientras el
## personaje camina reemplaza la ruta anterior, que es lo que hace que se pueda
## cambiar de rumbo a mitad de camino.
##
## Devuelve false si la celda no existe, esta bloqueada o no hay camino.
func ir_a_celda(destino : Vector2i) -> bool:
	var camino := grid.ruta(grid.mundo_a_celda(global_position), destino)
	if camino.is_empty():
		return false

	_ruta = camino
	estado = &"caminando"
	return true


## Detiene el recorrido en la celda a la que iba.
func detener() -> void:
	_ruta.clear()
	velocity = Vector3.ZERO
	estado = &"idle"


## Gira solo el avatar, nunca el cuerpo, para que la capsula de colision siga
## alineada a los ejes.
##
## El objetivo se calcula desde la posicion global del propio avatar y no desde
## la del cuerpo: look_at siempre se resuelve desde el nodo que gira, y apuntar
## a un punto que esta a otra altura lo inclina en vez de girarlo.
func _mirar_hacia(direccion : Vector3) -> void:
	var plano := Vector3(direccion.x, 0.0, direccion.z)
	if plano.length_squared() < 0.0001:
		return
	avatar.look_at(avatar.global_position + plano, Vector3.UP)
