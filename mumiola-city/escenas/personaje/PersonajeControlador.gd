class_name PersonajeControlador
extends CharacterBody3D

## Se emite al terminar un recorrido, con la celda en la que quedo el personaje.
signal llego_a_celda(celda : Vector2i)

## La grilla de la sala en la que esta parado el personaje.
##
## Se asigna desde el inspector solo en escenas de prueba de una sola sala. En el
## mundo real la reapunta entrar_en() cada vez que se cambia de sala, asi que
## puede estar en null mientras el personaje no este en ninguna.
@export var grid : IsoGrid
## La camara con la que se convierte un clic de pantalla en una celda. Tambien la
## reapunta entrar_en(): cada sala trae la suya.
@export var camara : Camera3D
## Metros por segundo. Con celdas de 1 metro, es tambien celdas por segundo.
@export var velocidad : float = 3.0

## idle | caminando | sentado | actuando
var estado : StringName = &"idle"

var _ruta : Array[Vector2i] = []

## En que esta sentado, si lo esta. Es una referencia a un nodo vivo, asi que
## vive aca y nunca en la instancia: no tiene sentido que siga siendo cierta
## manana (D3).
var _sentado_en : WorldObject = null

## El nodo que compone y orienta al avatar. Gira el, nunca el cuerpo.
@onready var avatar : AvatarComposer = $Visual


func _ready() -> void:
	avatar.reproducir(&"idle")


func _unhandled_input(evento : InputEvent) -> void:
	# Sin sala no hay a donde caminar. Pasa entre que el mundo arranca y que
	# alguien llama a entrar_en(), y tambien si una escena de prueba se olvido de
	# asignar los exports.
	if grid == null or camara == null:
		return

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

	if esta_sentado():
		levantarse()

	_ruta = camino
	estado = &"caminando"
	return true


## Detiene el recorrido en la celda a la que iba.
func detener() -> void:
	_ruta.clear()
	velocity = Vector3.ZERO
	estado = &"idle"


## Muda el personaje a una sala: reapunta sus referencias, lo para en la celda
## de entrada y descarta lo que estuviera recorriendo.
##
## Descartar la ruta no es opcional. Sin detener(), el personaje entra a la sala
## nueva y sigue caminando hacia una celda que era de la anterior, en una grilla
## donde esa celda significa otra cosa o directamente no existe.
func entrar_en(sala : RoomController) -> void:
	# Sin esto, cambiar de sala sentado deja _sentado_en apuntando a un mueble de
	# la sala anterior, que es una referencia viva a otro mundo.
	if esta_sentado():
		levantarse()
	detener()
	grid = sala.grid
	camara = sala.camara
	global_position = sala.posicion_de_entrada()
	avatar.reproducir(&"idle")


## Devuelve si el personaje esta sentado en algo.
func esta_sentado() -> bool:
	return _sentado_en != null


## Sienta al personaje en un objeto. Devuelve si pudo.
##
## Lo para sobre la celda del objeto y lo orienta como el objeto, que es lo que
## hace que se vea sentado *en* la silla y no al lado. El offset es para ajustar
## a ojo modelos cuyo asiento no esta en el centro de su celda.
func sentarse_en(objeto : WorldObject, offset : Vector2 = Vector2.ZERO,
		animacion : StringName = &"sentado") -> bool:
	if objeto == null or grid == null or esta_sentado():
		return false

	detener()

	var def := objeto.definicion()
	var size := Vector2i.ONE if def == null else def.tamano_grilla
	var pos := grid.centro_de(objeto.celda_origen, size, objeto.rotacion_grilla)
	pos.y = grid.altura_piso
	pos.x += offset.x
	pos.z += offset.y
	global_position = pos
	avatar.global_rotation.y = objeto.global_rotation.y

	_sentado_en = objeto
	estado = &"sentado"
	avatar.reproducir(animacion)
	return true


## Levanta al personaje y lo deja en una celda vecina libre. Devuelve si pudo.
##
## El paso al costado no es cosmetico: sentado queda parado sobre la celda del
## objeto, que esta ocupada, y desde una celda solida el A* no puede trazar
## ninguna ruta. Sin esto, levantarse dejaria al personaje clavado.
func levantarse() -> bool:
	if not esta_sentado():
		return false

	var destino := grid.celda_libre_vecina(_sentado_en.celda_origen)
	if destino != IsoGrid.SIN_CELDA:
		var pos := grid.celda_a_mundo(destino)
		pos.y = grid.altura_piso
		global_position = pos

	_sentado_en = null
	estado = &"idle"
	avatar.reproducir(&"idle")
	return true


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
