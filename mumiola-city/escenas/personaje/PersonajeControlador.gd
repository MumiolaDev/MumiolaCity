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
var _en_pose_sobre : WorldObject = null
## Con que animacion salir de la pose actual. La elige el mueble al entrar, asi
## que hay que recordarla: levantarse de una silla y de una cama no son lo mismo.
var _animacion_salida : StringName = &"levantarse"

## Hacia donde dar el paso al salir de la pose, en celdas. De una silla es hacia
## adelante; de una cama, hacia el costado.
var _paso_salida : Vector2i = Vector2i.ZERO

## El mueble del que se esta levantando ahora mismo, mientras dura la animacion.
var _saliendo_de : WorldObject = null

## A donde ir en cuanto termine de levantarse, si el jugador clickeo mientras.
var _destino_tras_pose : Vector2i = IsoGrid.SIN_CELDA

## Que hacer al terminar de caminar, si se camino para interactuar con algo.
var _pendiente_objeto : WorldObject = null
var _pendiente_verbo : InteractionBehavior = null

## El nodo que compone y orienta al avatar. Gira el, nunca el cuerpo.
@onready var avatar : AvatarComposer = $Visual


func _ready() -> void:
	# Se anota el mismo en vez de que el manager lo busque por ruta: asi cambiar
	# de lugar al personaje en el arbol no rompe nada.
	GameManager.registrar_jugador(self)
	# Levantarse termina cuando termina su animacion, no cuando se pide.
	avatar.transicion_terminada.connect(_al_terminar_transicion)
	avatar.reproducir(&"idle")


## Completa la salida de la pose en cuanto la animacion de levantarse termino.
func _al_terminar_transicion(_destino : StringName) -> void:
	if _saliendo_de != null:
		_terminar_salida()


func _unhandled_input(evento : InputEvent) -> void:
	# Sin sala no hay a donde caminar. Pasa entre que el mundo arranca y que
	# alguien llama a entrar_en(), y tambien si una escena de prueba se olvido de
	# asignar los exports.
	if grid == null or camara == null:
		return

	# Editando, el clic es del editor: colocar un mueble no tiene que hacer que
	# el personaje salga caminando hacia el.
	if GameManager.editando():
		return

	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		# Con un menu abierto, el clic es para cerrarlo y no para caminar. Cuando
		# el mundo ve el evento el menu todavia esta abierto: popup_hide llega
		# despues de _unhandled_input, no antes.
		if GameManager.hay_menu_abierto():
			return
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
			_resolver_pendiente()
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
	# Levantarse es una animacion, no un salto: se guarda a donde iba y se camina
	# recien cuando termino de incorporarse. Ademas resuelve un problema viejo:
	# en pose el personaje esta sobre una celda solida y el A* no traza rutas
	# desde ahi, asi que calcular el camino antes de salir daba siempre vacio.
	if esta_en_pose():
		_destino_tras_pose = destino
		dejar_pose()
		return true

	if estado == &"saliendo_pose":
		_destino_tras_pose = destino
		return true

	var camino := grid.ruta(grid.mundo_a_celda(global_position), destino)
	if camino.is_empty():
		return false

	_ruta = camino
	estado = &"caminando"
	return true


## Detiene el recorrido en la celda a la que iba.
func detener() -> void:
	_cancelar_pendiente()
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
	# Sin esto, cambiar de sala sentado deja _en_pose_sobre apuntando a un mueble de
	# la sala anterior, que es una referencia viva a otro mundo.
	if esta_en_pose():
		dejar_pose()
	_terminar_salida()
	detener()
	grid = sala.grid
	camara = sala.camara
	global_position = sala.posicion_de_entrada()
	avatar.reproducir(&"idle")


## Devuelve si el personaje esta en alguna pose sobre un mueble.
func esta_en_pose() -> bool:
	return _en_pose_sobre != null


## Pone al personaje en una pose sobre un objeto. Devuelve si pudo.
##
## Lo para sobre la celda del objeto y lo orienta como el objeto, que es lo que
## hace que se vea sentado *en* la silla y no al lado. El offset es para ajustar
## a ojo modelos cuyo asiento no esta en el centro de su celda.
##
## Recibe un diccionario y no seis parametros para que agregar un dato a la pose
## no cambie esta firma, y sobre todo para no tener que conocer PoseBehavior: lo
## unico que este metodo sabe es que le llegan un offset, un giro y tres nombres
## de animacion.
func adoptar_pose(objeto : WorldObject, pose : Dictionary) -> bool:
	if objeto == null or grid == null or esta_en_pose():
		return false

	# Si venia levantandose de otra cosa, se termina de levantar antes. Sin esto,
	# la salida pendiente se dispara despues —cuando la animacion de entrar a la
	# pose nueva termina— y teletransporta al personaje fuera del mueble en el
	# que se acaba de acomodar.
	_terminar_salida()

	var offset : Vector2 = pose.get("offset", Vector2.ZERO)
	var giro_grados : float = pose.get("giro", 180.0)
	var altura : float = pose.get("altura", 0.0)
	var entrada : StringName = pose.get("entrada", &"sentarse")
	var bucle : StringName = pose.get("bucle", &"sentado")
	_animacion_salida = pose.get("salida", &"levantarse")

	detener()

	var def := objeto.definicion()
	var size := Vector2i.ONE if def == null else def.tamano_grilla
	var pos := grid.centro_de(objeto.celda_origen, size, objeto.rotacion_grilla)
	pos.x += offset.x
	pos.z += offset.y
	# Las animaciones del pack estan hechas al ras del suelo, asi que sobre una
	# cama hay que subir el cuerpo hasta el colchon o el avatar queda enterrado.
	pos.y += altura
	global_position = pos

	# El modelo del mueble y el del avatar no tienen por que mirar al mismo lado,
	# asi que el desfase lo declara el comportamiento en vez de estar fijo aca.
	var giro := objeto.global_rotation.y + deg_to_rad(giro_grados)
	avatar.global_rotation.y = giro

	# Por donde salir es otra cosa que hacia donde se mira: de una silla se sale
	# por delante, pero de una cama se sale por el costado y no por la cabecera.
	var salida := objeto.global_rotation.y + deg_to_rad(pose.get("angulo_salida", giro_grados))
	var hacia := Vector3(-sin(salida), 0.0, -cos(salida))
	_paso_salida = Vector2i(roundi(hacia.x), roundi(hacia.z))

	_en_pose_sobre = objeto
	estado = &"en_pose"
	avatar.reproducir_encadenado(entrada, bucle)
	return true


## Saca al personaje de la pose y lo deja en una celda vecina libre.
##
## El paso al costado no es cosmetico: en pose queda parado sobre la celda del
## objeto, que esta ocupada, y desde una celda solida el A* no puede trazar
## ninguna ruta. Sin esto, levantarse dejaria al personaje clavado.
func dejar_pose() -> bool:
	if not esta_en_pose():
		return false

	var objeto := _en_pose_sobre

	# Soltar el asiento antes de avisarle al mueble corta la recursion:
	# PoseBehavior.salir() vuelve a llamar aca, y la guarda de arriba lo detiene
	# porque para entonces el personaje ya no esta en pose.
	_en_pose_sobre = null
	_desanotar_de(objeto)

	# El paso al costado se da al *terminar* la animacion y no antes. Moviendolo
	# primero, el personaje aparece de pie junto al mueble mientras todavia se
	# esta incorporando, que es lo que se veia al levantarse de la cama.
	estado = &"saliendo_pose"
	_saliendo_de = objeto
	if not avatar.reproducir_encadenado(_animacion_salida, &"idle"):
		# Sin animacion de salida no hay nada que esperar.
		_terminar_salida()
	return true


## Completa la salida de la pose: da el paso al costado y retoma lo pendiente.
##
## El paso no es cosmetico: en pose el personaje esta parado sobre la celda del
## mueble, que es solida, y desde una celda solida el A* no traza ninguna ruta.
## Sin esto, levantarse dejaria al personaje clavado.
func _terminar_salida() -> void:
	if _saliendo_de == null:
		return

	var objeto := _saliendo_de
	_saliendo_de = null

	var destino := _buscar_salida(objeto)
	if destino != IsoGrid.SIN_CELDA:
		global_position = grid.celda_a_mundo(destino)

	_paso_salida = Vector2i.ZERO
	estado = &"idle"

	var pendiente := _destino_tras_pose
	_destino_tras_pose = IsoGrid.SIN_CELDA
	if pendiente != IsoGrid.SIN_CELDA:
		ir_a_celda(pendiente)


## Busca donde pararse al salir de la pose.
##
## Avanza en la direccion de salida hasta dejar el mueble, y por eso no alcanza
## con mirar la celda de al lado: una cama de dos por tres tiene celdas propias a
## uno y dos pasos de distancia, y salir "al lado" seria salir encima de ella.
## Si por ese lado no hay lugar, sirve cualquier celda pegada a la huella.
func _buscar_salida(objeto : WorldObject) -> Vector2i:
	var desde := grid.mundo_a_celda(global_position)

	if _paso_salida != Vector2i.ZERO:
		for paso in range(1, 6):
			var celda := desde + _paso_salida * paso
			if grid.se_puede_caminar(celda):
				return celda

	var def := objeto.definicion()
	var size := Vector2i.ONE if def == null else def.tamano_grilla
	for propia in grid.celdas_de(objeto.celda_origen, size, objeto.rotacion_grilla):
		var vecina := grid.celda_libre_vecina(propia)
		if vecina != IsoGrid.SIN_CELDA:
			return vecina
	return IsoGrid.SIN_CELDA


## Avisa a los comportamientos del mueble que este actor ya no lo esta usando.
##
## Sin esto el mueble sigue contandolo como ocupante y no lo deja volver a
## sentarse, con la silla aparentemente libre. Levantarse tiene mas de un camino
## —la tecla, caminar a otro lado, cambiar de sala— y todos terminan aca, que es
## por que el aviso vive en levantarse() y no en cada uno de los que lo llaman.
##
## Los comportamientos se buscan por metodo y no por tipo, igual que ellos hacen
## con el actor: el personaje no tiene por que conocer PoseBehavior.
func _desanotar_de(objeto : WorldObject) -> void:
	if objeto == null or not is_instance_valid(objeto):
		return
	var def := objeto.definicion()
	if def == null:
		return
	for verbo in def.interacciones:
		if verbo != null and verbo.has_method(&"salir"):
			verbo.salir(self, objeto)


## Para al personaje en una celda concreta, sin caminar.
##
## Es lo que usa la carga de partida: el guardado dice en que celda estaba, no
## como llego. Si la celda no sirve —quedo ocupada por un mueble que se
## restauro antes— cae en una vecina libre antes que dejarlo dentro de algo.
func ubicar_en_celda(celda : Vector2i) -> void:
	if grid == null:
		return

	detener()
	if esta_en_pose():
		dejar_pose()

	var destino := celda
	if not grid.se_puede_caminar(destino):
		var alternativa := grid.celda_libre_vecina(celda)
		if alternativa != IsoGrid.SIN_CELDA:
			destino = alternativa

	var pos := grid.celda_a_mundo(destino)
	global_position = pos


## Reproduce una animacion de una pasada y vuelve a idle al terminar.
##
## Es lo que le da cuerpo a los verbos que no son poses: levantar algo, usarlo,
## saludar. No cambia el estado del personaje a proposito — un gesto no es un
## modo, y tratarlo como uno obligaria a cada verbo a acordarse de salir de el.
## Si el jugador clickea a mitad del gesto, camina, y eso esta bien: caminar
## pisa la animacion en el fotograma siguiente porque _physics_process la vuelve
## a pedir.
##
## Se niega en pose o levantandose: ahi la animacion la manda el mueble, y
## meterle un gesto en el medio deja al personaje de pie dentro de la cama.
##
## Devuelve si el gesto se reproduce.
func hacer_gesto(animacion : StringName, mirar_a : Vector3 = Vector3.ZERO) -> bool:
	if esta_en_pose() or estado == &"saliendo_pose":
		return false

	if mirar_a != Vector3.ZERO:
		_mirar_hacia(mirar_a - global_position)
	return avatar.reproducir_encadenado(animacion, &"idle")


## Ejecuta un verbo sobre un objeto, caminando hasta el primero si hace falta.
##
## Es lo que evita que interactuar con algo lejano teletransporte al personaje.
## Si el verbo pide adyacencia y no la hay, camina a una celda vecina del objeto
## y deja la accion anotada para ejecutarla al llegar.
##
## Devuelve si la accion se ejecuto ya, o si quedo en camino. Un false significa
## que ni siquiera se pudo empezar.
func interactuar_con(objeto : WorldObject, verbo : InteractionBehavior) -> bool:
	if objeto == null or verbo == null or grid == null:
		return false

	if not verbo.requiere_adyacencia or _esta_junto_a(objeto):
		return objeto.ejecutar(verbo, self)

	var destino := grid.celda_libre_vecina(objeto.celda_origen)
	if destino == IsoGrid.SIN_CELDA or not ir_a_celda(destino):
		return false

	# Despues de ir_a_celda, que limpia lo pendiente al llamar a detener().
	_pendiente_objeto = objeto
	_pendiente_verbo = verbo
	return true


## Devuelve si el personaje esta en una celda vecina al objeto, o encima de el.
func _esta_junto_a(objeto : WorldObject) -> bool:
	var mia := grid.mundo_a_celda(global_position)
	for celda in objeto.celdas_ocupadas(grid):
		if maxi(absi(mia.x - celda.x), absi(mia.y - celda.y)) <= 1:
			return true
	return false


## Ejecuta la accion que quedo pendiente al empezar a caminar.
func _resolver_pendiente() -> void:
	if _pendiente_objeto == null or _pendiente_verbo == null:
		return

	var objeto := _pendiente_objeto
	var verbo := _pendiente_verbo
	_pendiente_objeto = null
	_pendiente_verbo = null

	# El mueble pudo retirarse mientras el personaje iba caminando.
	if is_instance_valid(objeto):
		objeto.ejecutar(verbo, self)


## Olvida la accion pendiente.
##
## Se llama desde detener(), asi que un clic en otro lado a mitad de camino
## cancela la intencion: quien cambia de rumbo ya no quiere sentarse.
func _cancelar_pendiente() -> void:
	_pendiente_objeto = null
	_pendiente_verbo = null


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
