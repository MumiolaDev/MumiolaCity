extends Node

## Comprueba que un objeto de varias celdas reserve y libere todas las suyas.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Lo que mas importa aca es lo que comprueba al retirar: reservar N celdas es
## facil, liberarlas todas es donde se dejan celdas fantasma ocupadas que no se
## ven y que despues nadie explica.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var grid := sala.grid
	var fallos := 0

	for x in range(29, 40):
		for z in range(29, 40):
			grid.borrar_celda(CatalogoPiezas.PAREDES, Vector2i(x, z))
			grid.pintar(CatalogoPiezas.SUELO, Vector2i(x, z), &"suelo_base")
	grid.recalcular_paredes()

	for id in [&"tabla_madera", &"cama", &"alfombra", &"mesa", &"jamon", &"silla_madera"]:
		var def := ItemDatabase.obtener(id)
		var ancla := Vector2i(32, 32)
		var inst := ItemInstance.new()
		inst.definicion_id = id
		var codigo := sala.colocar_objeto(inst, ancla, 0)
		if not Errores.ok(codigo):
			print("  FALLO: no se pudo colocar %s: %s" % [id, Errores.mensaje(codigo)]); fallos += 1
			continue

		var esperadas := grid.celdas_de(ancla, def.tamano_grilla, 0)
		var ocupadas := 0
		for c in esperadas:
			if grid.objeto_en(c) != null:
				ocupadas += 1
		var libres_fuera := grid.objeto_en(ancla + def.tamano_grilla) == null
		print("  %-14s huella %s: %d de %d celdas reservadas, %s"
			% [id, def.tamano_grilla, ocupadas, esperadas.size(),
			   "no invade de mas" if libres_fuera else "INVADE DE MAS"])
		if ocupadas != esperadas.size() or not libres_fuera:
			fallos += 1

		# El A* tampoco entra en ninguna.
		for c in esperadas:
			if not grid.ruta(Vector2i(30, 30), c).is_empty():
				print("  FALLO: el A* llega a %s, ocupada por %s" % [c, id]); fallos += 1
				break

		# Y al retirarlo se liberan todas.
		var obj := grid.objeto_en(ancla)
		sala.retirar_objeto(obj)
		await get_tree().process_frame
		var quedan := 0
		for c in esperadas:
			if grid.objeto_en(c) != null:
				quedan += 1
		if quedan != 0:
			print("  FALLO: %s dejo %d celdas ocupadas al retirarse" % [id, quedan]); fallos += 1

	# Girado, la huella gira: lo que era N x M pasa a ocupar M x N. Se comprueba
	# contra la huella declarada y no contra un numero fijo, para que la prueba
	# siga valiendo cuando cambien los modelos.
	var largo := ItemDatabase.obtener(&"tabla_madera")
	if largo.tamano_grilla.x == largo.tamano_grilla.y:
		print("  (tabla_madera es cuadrada, el giro no se puede observar)")
	else:
		var inst2 := ItemInstance.new()
		inst2.definicion_id = largo.id
		sala.colocar_objeto(inst2, Vector2i(32, 32), 1)
		var en_columna := 0
		var en_fila := 0
		for d in range(29, 40):
			if grid.objeto_en(Vector2i(32, d)) != null: en_columna += 1
			if grid.objeto_en(Vector2i(d, 32)) != null: en_fila += 1
		print("  %s girada: %d en columna, %d en fila (declara %s)"
			% [largo.id, en_columna, en_fila, largo.tamano_grilla])
		if en_columna != largo.tamano_grilla.x or en_fila != largo.tamano_grilla.y:
			print("  FALLO: la huella no giro con el objeto"); fallos += 1

	print("HUELLA DE OBJETO: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
