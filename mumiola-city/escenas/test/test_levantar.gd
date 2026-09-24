extends Node

## Comprueba el verbo universal levantar.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Lo que se mide no es que el mueble desaparezca —eso ya lo hacia retirar_objeto()
## desde la fase 1— sino las cuatro reglas que lo hacen seguro: que pase por
## aplicar() y no por atras; que el objeto no se pueda perder entre la sala y la
## mochila; que vuelva **la misma** instancia con su estado; y que levantar
## jugando no ensucie el historial de deshacer del editor.

var _fallos := 0


func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var jugador := GameManager.jugador_actual()
	jugador.set_process_unhandled_input(false)
	InventoryManager.vaciar()

	await _probar_todos_lo_ofrecen(sala, jugador)
	await _probar_levantar(sala, jugador)
	await _probar_conserva_estado(sala, jugador)
	await _probar_inventario_lleno(sala, jugador)
	await _probar_ocupado(sala, jugador)
	await _probar_no_entra_al_historial(sala, jugador)
	await _probar_gesto(sala, jugador)

	print("LEVANTAR: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


## Todo mueble colocado ofrece levantar, y en el orden acordado.
func _probar_todos_lo_ofrecen(sala : RoomController, jugador : Node) -> void:
	var muestra : Array[StringName] = [&"silla_madera", &"mesa", &"cama", &"alfombra",
		&"lampara_mesa", &"maceta", &"estante", &"tomate"]
	var celda := Vector2i(4, 4)
	var sin_verbo : Array[String] = []
	var mal_ordenados : Array[String] = []

	for id in muestra:
		celda += Vector2i(0, 3)
		var inst := ItemInstance.new(); inst.definicion_id = id
		if not Errores.ok(sala.colocar_objeto(inst, celda, 0)):
			continue
		var obj := sala.grid.objeto_en(celda)
		await get_tree().process_frame

		var verbos := obj.verbos_disponibles(jugador)
		var nombres : Array[String] = []
		for v in verbos:
			nombres.append(String(v.verbo))
		if not ("levantar" in nombres):
			sin_verbo.append(String(id))
		# Levantar penultimo y mirar ultimo: levantar es destructivo y no tiene
		# que quedar bajo el cursor al abrirse el menu.
		elif nombres.size() < 2 or nombres[-1] != "mirar" or nombres[-2] != "levantar":
			mal_ordenados.append("%s: %s" % [id, str(nombres)])

		sala.aplicar(OperacionSala.retirar(celda), false)
		await get_tree().process_frame

	print("  %d de %d muebles ofrecen levantar" % [muestra.size() - sin_verbo.size(), muestra.size()])
	if not sin_verbo.is_empty():
		print("  FALLO: sin el verbo: %s" % str(sin_verbo)); _fallos += 1
	if not mal_ordenados.is_empty():
		print("  FALLO: orden del menu: %s" % str(mal_ordenados)); _fallos += 1


## Levantar saca el mueble de la sala, libera sus celdas y lo deja en la mochila.
func _probar_levantar(sala : RoomController, jugador : Node) -> void:
	InventoryManager.vaciar()
	var celda := Vector2i(6, 6)
	var obj := await _poner(sala, &"mesa", celda)
	if obj == null: return

	var huella := obj.celdas_ocupadas(sala.grid)
	var antes := InventoryManager.cantidad_de(&"mesa")
	var hecho : bool = obj.ejecutar(WorldObject.LEVANTAR, jugador)
	await get_tree().process_frame

	var libres := 0
	for c in huella:
		if sala.grid.se_puede_caminar(c):
			libres += 1
	print("  levantar mesa 2x2 -> hecho=%s  celdas liberadas %d/%d  en mochila %d"
		% [hecho, libres, huella.size(), InventoryManager.cantidad_de(&"mesa")])

	if not hecho:
		print("  FALLO: no se pudo levantar"); _fallos += 1
	if sala.grid.objeto_en(celda) != null:
		print("  FALLO: el mueble sigue en la sala"); _fallos += 1
	if libres != huella.size():
		print("  FALLO: quedaron celdas ocupadas por un mueble que ya no esta"); _fallos += 1
	if InventoryManager.cantidad_de(&"mesa") != antes + 1:
		print("  FALLO: no llego a la mochila"); _fallos += 1


## Vuelve la misma instancia, con el estado que tenia puesta en la sala.
##
## Es lo que separa levantar de destruir y volver a fabricar: la taza servida
## tiene que volver con su cafe.
func _probar_conserva_estado(sala : RoomController, jugador : Node) -> void:
	InventoryManager.vaciar()
	var celda := Vector2i(12, 6)
	var obj := await _poner(sala, &"olla", celda)
	if obj == null: return

	obj.instancia.contenido_id = &"tomate"
	obj.instancia.contenido_cantidad = 3
	var original := obj.instancia
	obj.ejecutar(WorldObject.LEVANTAR, jugador)
	await get_tree().process_frame

	var guardada : ItemInstance = null
	for s in InventoryManager.slots():
		if s.definicion_id == &"olla":
			guardada = s.instancia
	print("  olla con 3 tomates -> en mochila: %s (%s x%d)  misma instancia: %s"
		% [guardada != null, "" if guardada == null else guardada.contenido_id,
		   0 if guardada == null else guardada.contenido_cantidad, guardada == original])

	if guardada == null:
		print("  FALLO: la olla no llego a la mochila"); _fallos += 1
		return
	if guardada != original:
		print("  FALLO: volvio una copia y no la misma instancia"); _fallos += 1
	if guardada.contenido_id != &"tomate" or guardada.contenido_cantidad != 3:
		print("  FALLO: se perdio el contenido"); _fallos += 1


## Con la mochila llena el verbo sigue apareciendo, pero rechaza y no destruye.
##
## Que siga apareciendo es a proposito: un mueble que desaparece del menu cuando
## te queda poco espacio se lee como que el juego se rompio.
func _probar_inventario_lleno(sala : RoomController, jugador : Node) -> void:
	InventoryManager.vaciar()
	var celda := Vector2i(16, 6)
	var obj := await _poner(sala, &"silla_madera", celda)
	if obj == null: return

	# bol_sucio no se apila, asi que cuarenta unidades son las cuarenta casillas.
	InventoryManager.agregar(&"bol_sucio", InventoryManager.CASILLAS)
	var ofrecido : bool = WorldObject.LEVANTAR.puede_interactuar(jugador, obj)
	var hecho : bool = obj.ejecutar(WorldObject.LEVANTAR, jugador)
	await get_tree().process_frame

	var sigue := sala.grid.objeto_en(celda) != null
	print("  mochila llena -> el verbo aparece: %s  se ejecuto: %s  la silla sigue: %s"
		% [ofrecido, hecho, sigue])
	if not ofrecido:
		print("  FALLO: el verbo desaparecio del menu por falta de espacio"); _fallos += 1
	if hecho:
		print("  FALLO: levanto algo que no le entraba"); _fallos += 1
	if not sigue:
		print("  FALLO: el mueble se perdio entre la sala y la mochila"); _fallos += 1
	InventoryManager.vaciar()


## No se levanta un mueble que alguien esta usando.
func _probar_ocupado(sala : RoomController, jugador : Node) -> void:
	InventoryManager.vaciar()
	# La cama mide dos por tres, asi que necesita una zona despejada: en (20, 6)
	# de esta sala hay pared.
	var celda := Vector2i(10, 12)
	var obj := await _poner(sala, &"cama", celda)
	if obj == null: return

	var pose : PoseBehavior = load("res://data/objetos/comportamientos/acostarse.tres")
	obj.estado_runtime[PoseBehavior.CLAVE_OCUPANTES] = []
	jugador.adoptar_pose(obj, pose.datos_de_pose())
	obj.estado_runtime[PoseBehavior.CLAVE_OCUPANTES] = [GameManager.id_de_actor(jugador)]
	await get_tree().process_frame

	var ofrecido : bool = WorldObject.LEVANTAR.puede_interactuar(jugador, obj)
	print("  cama con alguien acostado -> ofrece levantar: %s" % ofrecido)
	if ofrecido:
		print("  FALLO: se puede levantar la cama con alguien encima"); _fallos += 1

	obj.estado_runtime[PoseBehavior.CLAVE_OCUPANTES] = []
	jugador.dejar_pose()
	for i in 600:
		await get_tree().process_frame
		if not jugador.esta_en_pose() and jugador.estado == &"idle":
			break
	sala.aplicar(OperacionSala.retirar(celda), false)
	await get_tree().process_frame


## Levantar jugando no entra al historial de deshacer del editor.
##
## Si entrara, un Ctrl+Z posterior devolveria el mueble a la sala y lo dejaria
## tambien en la mochila: el mismo objeto en dos lugares.
func _probar_no_entra_al_historial(sala : RoomController, jugador : Node) -> void:
	InventoryManager.vaciar()
	sala.olvidar_historial()
	var celda := Vector2i(24, 6)
	var obj := await _poner(sala, &"banqueta", celda)
	if obj == null: return

	obj.ejecutar(WorldObject.LEVANTAR, jugador)
	await get_tree().process_frame

	var hay_historial : bool = sala.puede_deshacer()
	sala.deshacer()
	await get_tree().process_frame
	var revivio := sala.grid.objeto_en(celda) != null
	print("  tras levantar -> hay algo que deshacer: %s  Ctrl+Z la revive: %s  en mochila: %d"
		% [hay_historial, revivio, InventoryManager.cantidad_de(&"banqueta")])

	if hay_historial or revivio:
		print("  FALLO: levantar jugando quedo en el historial del editor"); _fallos += 1
	if InventoryManager.cantidad_de(&"banqueta") != 1:
		print("  FALLO: la banqueta no quedo en la mochila"); _fallos += 1


## El personaje hace el gesto de agacharse y vuelve solo a idle.
##
## Se comprueba porque el fallo es mudo: si el clip del pack estuviera mal
## escrito, reproducir_encadenado() cae en reproducir(destino) y el personaje
## levanta el mueble sin moverse, sin ningun error en consola.
func _probar_gesto(sala : RoomController, jugador : Node) -> void:
	InventoryManager.vaciar()
	var celda := Vector2i(14, 12)
	var obj := await _poner(sala, &"maceta", celda)
	if obj == null: return

	obj.ejecutar(WorldObject.LEVANTAR, jugador)
	await get_tree().process_frame
	var durante : StringName = jugador.avatar.animacion_actual()

	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000:
		await get_tree().process_frame
		if jugador.avatar.animacion_actual() == &"idle":
			break
	print("  gesto al levantar: %s -> %s" % [durante, jugador.avatar.animacion_actual()])

	if durante != &"levantar":
		print("  FALLO: no se reprodujo la animacion de levantar"); _fallos += 1
	if jugador.avatar.animacion_actual() != &"idle":
		print("  FALLO: el gesto no volvio a idle"); _fallos += 1


## Coloca un item y devuelve su objeto, o null avisando si no se pudo.
func _poner(sala : RoomController, id : StringName, celda : Vector2i) -> WorldObject:
	var inst := ItemInstance.new(); inst.definicion_id = id
	var codigo := sala.colocar_objeto(inst, celda, 0)
	if not Errores.ok(codigo):
		print("  FALLO: no se pudo colocar %s (%s)" % [id, Errores.mensaje(codigo)]); _fallos += 1
		return null
	await get_tree().process_frame
	return sala.grid.objeto_en(celda)
