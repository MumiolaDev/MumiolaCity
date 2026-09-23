extends Node

## Comprueba que levantarse de una pose sea una animacion y no un salto.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Tres cosas, y las tres se vieron rotas en la cama: que el personaje no se
## mueva hasta que la animacion de incorporarse termino; que salga por el
## costado y no por la cabecera; y que adoptar otra pose mientras se levanta no
## deje una salida pendiente que lo teletransporte despues.

## Cuanto esperar como mucho a que una animacion termine, en milisegundos.
##
## Por reloj y no por cuadros: Lie_Down dura tres segundos y la ventana corre a
## cien cuadros por segundo, asi que contar trescientos cuadros se quedaba justo
## corto y la prueba media al personaje a mitad de la transicion.
const ESPERA_MAXIMA := 12000

var _fallos := 0


func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var jugador := GameManager.jugador_actual()
	# Un clic perdido sobre la ventana manda a caminar y saca de la pose sola.
	jugador.set_process_unhandled_input(false)

	var pose : PoseBehavior = load("res://data/objetos/comportamientos/acostarse.tres")
	var celda := Vector2i(8, 8)
	var inst := ItemInstance.new(); inst.definicion_id = &"cama"
	if not Errores.ok(sala.colocar_objeto(inst, celda, 0)):
		print("FALLO: no se pudo colocar la cama"); _terminar()
		return
	var cama := sala.grid.objeto_en(celda)
	await get_tree().process_frame

	await _probar_salida_diferida(sala, jugador, pose, cama)
	await _probar_salida_lateral(sala, jugador, pose, cama)
	await _probar_pose_encima_de_salida(sala, jugador, pose, cama)
	await _probar_destino_pendiente(sala, jugador, pose, cama)
	_terminar()


## El personaje no se mueve hasta que la animacion de levantarse termino.
func _probar_salida_diferida(sala : RoomController, jugador : Node,
		pose : PoseBehavior, cama : WorldObject) -> void:
	await _entrar(jugador, pose, cama)
	var en_la_cama : Vector3 = jugador.global_position

	jugador.dejar_pose()
	# Un puñado de cuadros: la animacion dura dos segundos largos, asi que aca
	# todavia se esta incorporando.
	for i in 10: await get_tree().process_frame

	var movido : float = jugador.global_position.distance_to(en_la_cama)
	print("  a mitad de levantarse: estado=%s  se movio %.3f m" % [jugador.estado, movido])
	if movido > 0.001:
		print("  FALLO: se movio antes de terminar de incorporarse"); _fallos += 1
	if jugador.estado != &"saliendo_pose":
		print("  FALLO: el estado no es saliendo_pose"); _fallos += 1

	await _esperar_animacion(jugador, &"idle")
	var salto : float = jugador.global_position.distance_to(en_la_cama)
	print("  al terminar: estado=%s  se movio %.3f m" % [jugador.estado, salto])
	if salto < 0.5:
		print("  FALLO: nunca dio el paso al costado"); _fallos += 1
	if jugador.estado != &"idle":
		print("  FALLO: no quedo idle al terminar"); _fallos += 1


## Se sale por el costado de la cama y no por la cabecera.
##
## La cama mide dos por tres, asi que su lado largo es z: salir por el costado
## es cambiar de columna sin cambiar de fila. Salir por la cabecera dejaba al
## personaje asomado por arriba, que es lo que se veia.
func _probar_salida_lateral(sala : RoomController, jugador : Node,
		pose : PoseBehavior, cama : WorldObject) -> void:
	await _entrar(jugador, pose, cama)
	var desde := sala.grid.mundo_a_celda(jugador.global_position)
	jugador.dejar_pose()
	await _esperar_animacion(jugador, &"idle")
	var hasta := sala.grid.mundo_a_celda(jugador.global_position)

	var def := cama.definicion()
	var huella := sala.grid.celdas_de(cama.celda_origen, def.tamano_grilla, cama.rotacion_grilla)
	print("  salio de %s a %s  (huella %s)" % [desde, hasta, huella])
	if hasta in huella:
		print("  FALLO: quedo parado encima de la cama"); _fallos += 1
	if hasta.y != desde.y:
		print("  FALLO: salio a lo largo de la cama y no por el costado"); _fallos += 1
	if not sala.grid.se_puede_caminar(hasta):
		print("  FALLO: quedo en una celda por la que no se camina"); _fallos += 1


## Acostarse otra vez mientras se esta levantando no deja una salida pendiente.
##
## Sin esto la salida se disparaba despues —cuando terminaba la animacion de
## entrar en la pose nueva— y sacaba al personaje del mueble en el que se
## acababa de acomodar.
func _probar_pose_encima_de_salida(sala : RoomController, jugador : Node,
		pose : PoseBehavior, cama : WorldObject) -> void:
	await _entrar(jugador, pose, cama)
	jugador.dejar_pose()
	for i in 5: await get_tree().process_frame

	cama.estado_runtime[PoseBehavior.CLAVE_OCUPANTES] = []
	if not jugador.adoptar_pose(cama, pose.datos_de_pose()):
		print("  FALLO: no se pudo volver a la cama mientras se levantaba"); _fallos += 1
		return
	var en_la_cama : Vector3 = jugador.global_position
	await _esperar_animacion(jugador, pose.animacion_bucle)
	for i in 30: await get_tree().process_frame

	var corrido : float = jugador.global_position.distance_to(en_la_cama)
	print("  volver a la pose mientras se levantaba: se corrio %.3f m  en_pose=%s"
		% [corrido, jugador.esta_en_pose()])
	if corrido > 0.001:
		print("  FALLO: la salida pendiente lo saco de la cama"); _fallos += 1
	if not jugador.esta_en_pose():
		print("  FALLO: no quedo en pose"); _fallos += 1


## Pedirle caminar mientras esta en pose lo levanta primero y camina despues.
func _probar_destino_pendiente(sala : RoomController, jugador : Node,
		pose : PoseBehavior, cama : WorldObject) -> void:
	if not jugador.esta_en_pose():
		await _entrar(jugador, pose, cama)

	var destino := Vector2i(3, 3)
	if not sala.grid.se_puede_caminar(destino):
		print("  AVISO: la celda de prueba no es caminable, se omite"); return

	jugador.ir_a_celda(destino)
	for i in 10: await get_tree().process_frame
	if jugador.estado != &"saliendo_pose":
		print("  FALLO: caminar en pose no arranco por levantarse"); _fallos += 1

	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ESPERA_MAXIMA:
		await get_tree().process_frame
		if sala.grid.mundo_a_celda(jugador.global_position) == destino:
			break
	var llego := sala.grid.mundo_a_celda(jugador.global_position)
	print("  pedido caminar estando acostado -> llego a %s (pedido %s)" % [llego, destino])
	if llego != destino:
		print("  FALLO: no retomo el destino despues de levantarse"); _fallos += 1


## Mete al personaje en la pose y espera a que la transicion termine.
func _entrar(jugador : Node, pose : PoseBehavior, cama : WorldObject) -> void:
	if jugador.esta_en_pose():
		jugador.dejar_pose()
		await _esperar_animacion(jugador, &"idle")
	cama.estado_runtime[PoseBehavior.CLAVE_OCUPANTES] = []
	jugador.adoptar_pose(cama, pose.datos_de_pose())
	await _esperar_animacion(jugador, pose.animacion_bucle)


## Espera a que el avatar este reproduciendo una animacion concreta.
func _esperar_animacion(jugador : Node, cual : StringName) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ESPERA_MAXIMA:
		await get_tree().process_frame
		if jugador.avatar.animacion_actual() == cual:
			return
	print("  AVISO: se agoto la espera de la animacion %s" % cual)


func _terminar() -> void:
	print("SALIDA DE POSE: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()
