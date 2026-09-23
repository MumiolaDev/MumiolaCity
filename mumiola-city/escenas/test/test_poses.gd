extends Node

## Comprueba las tres poses y que los ocupantes se guarden por id de actor.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Lo que mas importa no es que sentarse funcione —ya funcionaba— sino que el
## mueble anote un **id** y no un nodo. Es la quinta costura del multijugador: un
## nodo del cliente A no existe en el B, asi que lo que se replica es el hecho y
## cada cliente resuelve su propio nodo.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var jugador := GameManager.jugador_actual()
	var fallos := 0

	var id := GameManager.id_de_actor(jugador)
	print("id del jugador: '%s'" % id)
	if id == &"":
		print("FALLO: el jugador no quedo anotado como actor"); fallos += 1
	if GameManager.actor_por_id(id) != jugador:
		print("FALLO: el id no resuelve de vuelta al jugador"); fallos += 1

	var casos := [
		{"item": &"silla_madera", "verbo": &"sentarse", "bucle": &"sentado"},
		{"item": &"cama", "verbo": &"acostarse", "bucle": &"acostado"},
		{"item": &"alfombra", "verbo": &"sentarse_piso", "bucle": &"sentado_piso"},
	]

	var celda := Vector2i(10, 10)
	for caso in casos:
		var def := ItemDatabase.obtener(caso["item"])
		# El comportamiento se carga de su .tres y no de la definicion, para que
		# la prueba mida el mecanismo y no si alguien corrio el importador. Que
		# la definicion lo traiga o no se reporta aparte.
		var pose : PoseBehavior = load("res://data/objetos/comportamientos/%s.tres" % caso["verbo"])
		if pose == null:
			print("FALLO: no existe el comportamiento %s" % caso["verbo"]); fallos += 1
			continue

		var en_el_catalogo := false
		for v in def.interacciones:
			if v is PoseBehavior and v.verbo == caso["verbo"]:
				en_el_catalogo = true
		if not en_el_catalogo:
			print("  AVISO: %s todavia no trae %s en su definicion (falta reimportar)"
				% [caso["item"], caso["verbo"]])

		var inst := ItemInstance.new(); inst.definicion_id = caso["item"]
		celda += Vector2i(4, 0)
		if not Errores.ok(sala.colocar_objeto(inst, celda, 0)):
			print("FALLO: no se pudo colocar %s" % caso["item"]); fallos += 1
			continue
		var obj := sala.grid.objeto_en(celda)
		await get_tree().process_frame

		# Entrar en la pose.
		if not obj.ejecutar(pose, jugador):
			print("FALLO: %s no se pudo ejecutar" % caso["verbo"]); fallos += 1
			continue
		if not jugador.esta_en_pose():
			print("FALLO: el jugador no quedo en pose tras %s" % caso["verbo"]); fallos += 1

		var dentro : Array = pose.ocupantes(obj)
		var por_id : bool = dentro.size() == 1 and dentro[0] is StringName
		print("  %-14s ocupantes=%s  por id: %s  etiqueta ahora: '%s'"
			% [caso["verbo"], str(dentro), por_id, pose.etiqueta_para(jugador, obj)])
		if not por_id:
			print("  FALLO: los ocupantes no son ids"); fallos += 1
		if dentro.size() == 1 and dentro[0] != id:
			print("  FALLO: se anoto otro id"); fallos += 1
		if pose.etiqueta_para(jugador, obj) != pose.etiqueta_salir:
			print("  FALLO: la etiqueta no cambio a salir"); fallos += 1

		# El mismo verbo lo saca.
		if not obj.ejecutar(pose, jugador):
			print("  FALLO: no se pudo salir de la pose"); fallos += 1
		if jugador.esta_en_pose():
			print("  FALLO: el jugador quedo en pose tras salir"); fallos += 1
		if not pose.ocupantes(obj).is_empty():
			print("  FALLO: el mueble quedo ocupado"); fallos += 1

		# Y se puede volver a entrar, que es el bug que tuvo la version vieja.
		if not obj.ejecutar(pose, jugador):
			print("  FALLO: no se pudo volver a entrar"); fallos += 1
		obj.ejecutar(pose, jugador)
		await get_tree().process_frame

	# Un id que ya no resuelve no deja el mueble ocupado para siempre.
	var inst2 := ItemInstance.new(); inst2.definicion_id = &"silla_madera"
	var celda2 := Vector2i(6, 14)
	sala.colocar_objeto(inst2, celda2, 0)
	await get_tree().process_frame
	var silla := sala.grid.objeto_en(celda2)
	var pose2 : PoseBehavior = load("res://data/objetos/comportamientos/sentarse.tres")
	silla.estado_runtime[PoseBehavior.CLAVE_OCUPANTES] = [&"fantasma_que_no_existe"]
	var limpio : Array = pose2.ocupantes(silla)
	print("silla con un id fantasma -> ocupantes: %s" % str(limpio))
	if not limpio.is_empty():
		print("FALLO: un id muerto deja la silla ocupada para siempre"); fallos += 1
	if not pose2.puede_interactuar(jugador, silla):
		print("FALLO: la silla no se libero"); fallos += 1

	print("POSES: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
