extends Node

## Comprueba el cambio de sala: ir, volver, y que nada se pierda en el camino.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. Escribe en user://salas; ver test_servidor.
##
## Lo que se mide es lo que el cambio a salas bajo demanda puso en juego: que
## haya una sola sala viva; que la de antes se guarde al dejarla y vuelva igual;
## que un pedido que falla deje al jugador donde estaba y no en el vacio; que dos
## pedidos cruzados no dejen al jugador en la que llego ultima; que el jugador
## salga sentado de una sala y entre parado en la otra; y que el chat de una sala
## no se escuche en otra.

var _fallos := 0


func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var jugador := GameManager.jugador_actual()
	jugador.set_process_unhandled_input(false)

	var plaza := GameManager.sala_actual()
	_comprobar(plaza != null and plaza.id_sala == GameManager.SALA_INICIAL,
		"el mundo arranca en la plaza, pedida al servidor")
	_comprobar(plaza.nombre_sala == "Plaza", "con su nombre del documento")
	_comprobar(_salas_vivas() == 1, "hay una sola sala viva")

	var creada : Dictionary = await Servidor.crear_sala("Prueba de viaje", &"cuadrada_chica", GameManager.perfil_id())
	var casa : StringName = creada.id
	_comprobar(Errores.ok(creada.codigo), "se crea una sala propia")

	# --- ir ---
	var salidas := [0]
	GameManager.saliendo_de_sala.connect(func(_s : RoomController) -> void: salidas[0] += 1)
	var codigo : Errores.Codigo = await GameManager.ir_a(casa)
	await get_tree().process_frame
	var sala := GameManager.sala_actual()
	_comprobar(Errores.ok(codigo) and sala.id_sala == casa, "ir_a lleva a la sala nueva")
	_comprobar(not is_instance_valid(plaza), "la plaza se libero")
	_comprobar(_salas_vivas() == 1, "sigue habiendo una sola sala viva")
	_comprobar(salidas[0] == 1, "se aviso la salida una vez")
	_comprobar(sala.grid.mundo_a_celda(jugador.global_position) == sala.celda_entrada,
		"el jugador aparece en la entrada")
	_comprobar(jugador.grid == sala.grid, "y camina sobre la grilla nueva")
	_comprobar(not Transicion.esta_cubierto(), "el telon quedo abierto")

	# --- editar, irse y volver ---
	sala.aplicar(OperacionSala.colocar(&"mesa", Vector2i(4, 4), 0))
	sala.aplicar(OperacionSala.colocar(&"silla_madera", Vector2i(3, 5), 0))
	var antes := JSON.stringify(sala.to_dict().objetos)
	await GameManager.ir_a(GameManager.SALA_INICIAL)
	_comprobar(GameManager.sala_actual().id_sala == GameManager.SALA_INICIAL, "vuelve a la plaza")
	await GameManager.ir_a(casa)
	_comprobar(JSON.stringify(GameManager.sala_actual().to_dict().objetos) == antes,
		"los muebles siguen ahi al volver: se guardo al irse")

	# --- sentado al irse ---
	var silla := GameManager.sala_actual().grid.objeto_en(Vector2i(3, 5))
	var sentarse : PoseBehavior = load("res://data/objetos/comportamientos/sentarse.tres")
	if silla != null and silla.ejecutar(sentarse, jugador) and jugador.esta_en_pose():
		await GameManager.ir_a(GameManager.SALA_INICIAL)
		_comprobar(not jugador.esta_en_pose(), "irse sentado lo levanta")
	else:
		await GameManager.ir_a(GameManager.SALA_INICIAL)
		print("  (no se pudo sentar para probar la salida sentado)")

	# --- rechazos ---
	_comprobar((await GameManager.ir_a(GameManager.SALA_INICIAL)) == Errores.Codigo.ES_LA_SALA_ACTUAL,
		"ir a donde ya estas se rechaza")
	var donde := GameManager.sala_actual()
	_comprobar((await GameManager.ir_a(&"s_no_existe")) == Errores.Codigo.SALA_NO_EXISTE,
		"ir a una sala que no existe se rechaza")
	_comprobar(GameManager.sala_actual() == donde and is_instance_valid(donde),
		"y el jugador sigue donde estaba")
	_comprobar(not Transicion.esta_cubierto(), "sin quedar a oscuras")

	# Dos pedidos cruzados: el segundo se rechaza mientras el primero esta en curso.
	Transicion.descubrir()
	await get_tree().process_frame
	GameManager.ir_a(casa)
	var segundo : Errores.Codigo = await GameManager.ir_a(GameManager.SALA_INICIAL)
	_comprobar(segundo == Errores.Codigo.CAMBIO_EN_CURSO, "un segundo pedido en medio se rechaza")
	while GameManager.cambiando_de_sala():
		await get_tree().process_frame
	_comprobar(GameManager.sala_actual().id_sala == casa, "y gana el primero")

	# --- el chat es de la sala ---
	Consola.limpiar()
	Servidor.chat_recibido.emit(GameManager.SALA_INICIAL, &"otro", "Otro", "hola plaza")
	Servidor.chat_recibido.emit(casa, &"otro", "Otro", "hola casa")
	var textos := Consola.historial().map(func(m : Dictionary) -> String: return m.texto)
	_comprobar("hola casa" in textos and not ("hola plaza" in textos),
		"se escucha solo lo que se dice en tu sala (%s)" % [textos])

	await GameManager.ir_a(GameManager.SALA_INICIAL)
	await Servidor.borrar_sala(casa, GameManager.perfil_id())

	print("IR A SALA: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _salas_vivas() -> int:
	var n := 0
	for hijo in get_tree().root.find_child("Salas", true, false).get_children():
		if hijo is RoomController and not hijo.is_queued_for_deletion():
			n += 1
	return n


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
