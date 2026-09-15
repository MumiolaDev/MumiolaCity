class_name PersonajeControlador
extends CharacterBody3D

## Se emite al terminar un recorrido, con la celda en la que quedo el personaje.
signal llego_a_celda(celda : Vector2i)

## Valor que devuelve celda_bajo_puntero() cuando el rayo no corta el plano del
## piso. Solo puede pasar si la camara mira exactamente en horizontal.
const SIN_CELDA := Vector2i.MAX

## La grilla de la sala en la que esta parado el personaje.
@export var grid : IsoGrid
## La camara con la que se convierte un clic de pantalla en una celda.
@export var camara : Camera3D
## Metros por segundo. Con celdas de 1 metro, es tambien celdas por segundo.
@export var velocidad : float = 3.0

## idle | caminando | sentado | actuando
var estado : StringName = &"idle"

var _astar : AStarGrid2D
var _ruta : Array[Vector2i] = []

## El nodo que compone y orienta al avatar. Gira el, nunca el cuerpo.
@onready var avatar : AvatarComposer = $Visual


func _ready() -> void:
	_construir_astar()
	grid.ocupacion_cambiada.connect(_on_ocupacion_cambiada)
	avatar.reproducir(&"idle")


func _unhandled_input(evento : InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var celda := celda_bajo_puntero(evento.position)
		if celda != SIN_CELDA:
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


## Convierte una posicion de pantalla en la celda del piso a la que apunta.
##
## Intersecta el rayo de la camara contra un plano horizontal, asi que no hace
## falta que el escenario tenga colision. El plano va a la altura de los pies
## del personaje y no a y=0: la cara superior del suelo esta por encima del
## origen, y cortar el plano equivocado desplaza el resultado de costado casi
## una celda entera.
##
## Devuelve [constant SIN_CELDA] si el rayo no corta el plano. La celda devuelta
## puede no tener suelo: eso lo decide quien llama.
func celda_bajo_puntero(pos_pantalla : Vector2) -> Vector2i:
	var origen := camara.project_ray_origin(pos_pantalla)
	var direccion := camara.project_ray_normal(pos_pantalla)
	var plano := Plane(Vector3.UP, global_position.y)
	var golpe = plano.intersects_ray(origen, direccion)
	if golpe == null:
		return SIN_CELDA
	return grid.mundo_a_celda(golpe)


## Calcula la ruta hasta una celda y empieza a recorrerla. Llamarla mientras el
## personaje camina reemplaza la ruta anterior, que es lo que hace que se pueda
## cambiar de rumbo a mitad de camino.
##
## Devuelve false si la celda no existe, esta bloqueada o no hay camino.
func ir_a_celda(destino : Vector2i) -> bool:
	if not _astar.region.has_point(destino) or _astar.is_point_solid(destino):
		return false

	var origen := grid.mundo_a_celda(global_position)
	if not _astar.region.has_point(origen):
		return false

	var camino := _astar.get_id_path(origen, destino)
	if camino.size() < 2:
		return false

	_ruta.assign(camino)
	_ruta.remove_at(0)  # la primera celda es en la que ya estoy parado
	estado = &"caminando"
	return true


## Detiene el recorrido en la celda a la que iba.
func detener() -> void:
	_ruta.clear()
	velocity = Vector3.ZERO
	estado = &"idle"


## Arma el AStarGrid2D sobre la region de suelo pintado y marca como solidas las
## celdas por las que no se puede caminar.
func _construir_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = grid.region_usada()
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()

	var region := _astar.region
	for x in region.size.x:
		for z in region.size.y:
			var celda := region.position + Vector2i(x, z)
			_astar.set_point_solid(celda, not grid.esta_libre(celda))


## El AStarGrid2D mantiene su propia copia de celdas solidas, independiente del
## diccionario de IsoGrid. Esta es la funcion que las mantiene sincronizadas, y
## por eso parchea solo las celdas que cambiaron en vez de reconstruir todo.
func _on_ocupacion_cambiada(celdas : Array[Vector2i]) -> void:
	for celda in celdas:
		if _astar.region.has_point(celda):
			_astar.set_point_solid(celda, not grid.esta_libre(celda))


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
