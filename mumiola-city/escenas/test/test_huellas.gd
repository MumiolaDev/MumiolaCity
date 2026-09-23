extends Node

## Comprueba que una pieza de varias celdas bloquee todas las que cubre.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Comprueba tambien que las celdas bloqueadas queden todas en la misma linea:
## una pared que engorde hacia el fondo se ve bien y hace la sala mas chica sin
## que se note, hasta que el personaje no puede pasar por donde deberia.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var grid := GameManager.sala_actual().grid
	var fallos := 0

	var esperado := {
		&"pilar_base": 1, &"pared_base": 1, &"pared_doble_base": 2,
		&"espacio_puerta": 3, &"ventana_cerrada": 2, &"ventana_abierta": 2,
	}

	for pieza in esperado:
		_limpiar(grid)
		grid.pintar(CatalogoPiezas.PAREDES, Vector2i(33, 33), pieza, 0)
		grid.recalcular_paredes()
		var b := _bloqueadas(grid)
		var ok : bool = b.size() == esperado[pieza]
		print("  %-18s bloquea %d %s (esperadas %d) %s"
			% [pieza, b.size(), str(b), esperado[pieza], "ok" if ok else "MAL"])
		if not ok: fallos += 1
		if not grid.hay_pared(Vector2i(33, 33)):
			print("  FALLO: %s no bloquea su propia celda" % pieza); fallos += 1
		var lineas := {}
		for c in b: lineas[c.y] = true
		if lineas.size() != 1:
			print("  FALLO: %s bloquea en %d lineas distintas" % [pieza, lineas.size()]); fallos += 1

	_limpiar(grid)
	grid.pintar(CatalogoPiezas.PAREDES, Vector2i(33, 33), &"espacio_puerta",
		CatalogoPiezas.orientacion_de(1))
	grid.recalcular_paredes()
	var b2 := _bloqueadas(grid)
	var columnas := {}
	for c in b2: columnas[c.x] = true
	print("  espacio_puerta girada: %d celdas en %d columnas %s" % [b2.size(), columnas.size(), str(b2)])
	if b2.size() != 3 or columnas.size() != 1:
		print("  FALLO: la huella no giro con la pieza"); fallos += 1

	_limpiar(grid)
	grid.pintar(CatalogoPiezas.PAREDES, Vector2i(33, 33), &"espacio_puerta", 0)
	grid.recalcular_paredes()
	var invadida := Vector2i(32, 33)
	if not grid.hay_pared(invadida):
		print("  FALLO: (32,33) deberia estar invadida"); fallos += 1
	elif not grid.ruta(Vector2i(30, 33), invadida).is_empty():
		print("  FALLO: el A* encontro ruta hasta una celda invadida"); fallos += 1
	else:
		print("  el A* no entra en una celda invadida")

	print("HUELLAS: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()

func _limpiar(grid : IsoGrid) -> void:
	for x in range(29, 38):
		for z in range(29, 38):
			grid.borrar_celda(CatalogoPiezas.PAREDES, Vector2i(x, z))
			grid.pintar(CatalogoPiezas.SUELO, Vector2i(x, z), &"suelo_base")
	grid.recalcular_paredes()

func _bloqueadas(grid : IsoGrid) -> Array[Vector2i]:
	var salida : Array[Vector2i] = []
	for x in range(29, 38):
		for z in range(29, 38):
			if grid.hay_pared(Vector2i(x, z)):
				salida.append(Vector2i(x, z))
	return salida
