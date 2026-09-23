extends Node

## Comprueba que ocupar y bloquear el paso sean dos cosas distintas.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Los dos casos que motivaron la separacion: la alfombra, que reserva sus celdas
## para que no le pongas una mesa encima pero se pisa, y el hueco de un vano, que
## esta ocupado —ahi va a ir una puerta— pero se cruza caminando.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var grid := sala.grid
	var fallos := 0

	for x in range(29, 42):
		for z in range(29, 42):
			grid.borrar_celda(CatalogoPiezas.PAREDES, Vector2i(x, z))
			grid.pintar(CatalogoPiezas.SUELO, Vector2i(x, z), &"suelo_base")
	grid.recalcular_paredes()

	# --- el vano: los costados bloquean, el hueco no, y los tres ocupan ---
	grid.pintar(CatalogoPiezas.PAREDES, Vector2i(35, 35), &"espacio_puerta", 0)
	grid.recalcular_paredes()
	var hueco := Vector2i(35, 35)
	var lado := Vector2i(34, 35)
	print("hueco  : estructura=%s  pared=%s  se_camina=%s"
		% [grid.hay_estructura(hueco), grid.hay_pared(hueco), grid.se_puede_caminar(hueco)])
	print("costado: estructura=%s  pared=%s  se_camina=%s"
		% [grid.hay_estructura(lado), grid.hay_pared(lado), grid.se_puede_caminar(lado)])
	if not grid.hay_estructura(hueco) or grid.hay_pared(hueco) or not grid.se_puede_caminar(hueco):
		print("FALLO: el hueco deberia ocupar, no bloquear y dejar caminar"); fallos += 1
	if not grid.hay_estructura(lado) or not grid.hay_pared(lado) or grid.se_puede_caminar(lado):
		print("FALLO: el costado deberia ocupar y bloquear"); fallos += 1

	# No se le puede poner un mueble al hueco: ahi va a ir una puerta.
	var inst := ItemInstance.new(); inst.definicion_id = &"silla_madera"
	var codigo := sala.colocar_objeto(inst, hueco, 0)
	if Errores.ok(codigo):
		print("FALLO: se pudo poner un mueble en el hueco de la puerta"); fallos += 1
	else:
		print("el hueco no acepta muebles: %s" % Errores.mensaje(codigo))

	# Pero se cruza: hay ruta de un lado al otro atravesandolo.
	var ruta := grid.ruta(Vector2i(35, 33), Vector2i(35, 37))
	var cruza := hueco in ruta
	print("ruta a traves del vano: %d pasos, pasa por el hueco: %s" % [ruta.size(), cruza])
	if ruta.is_empty():
		print("FALLO: no hay forma de cruzar el vano"); fallos += 1

	# --- la alfombra: ocupa pero se pisa ---
	for x in range(29, 42):
		for z in range(29, 42):
			grid.borrar_celda(CatalogoPiezas.PAREDES, Vector2i(x, z))
	grid.recalcular_paredes()

	var def := ItemDatabase.obtener(&"alfombra")
	# Se fuerza en memoria en vez de confiar en el catalogo: asi la prueba
	# comprueba el mecanismo y no si alguien ya corrio el importador.
	def.bloquea_paso = false
	var inst2 := ItemInstance.new(); inst2.definicion_id = &"alfombra"
	var ancla := Vector2i(35, 35)
	if not Errores.ok(sala.colocar_objeto(inst2, ancla, 0)):
		print("FALLO: no se pudo colocar la alfombra"); fallos += 1
	else:
		var celdas := grid.celdas_de(ancla, def.tamano_grilla, 0)
		var ocupadas := 0
		var caminables := 0
		for c in celdas:
			if grid.objeto_en(c) != null: ocupadas += 1
			if grid.se_puede_caminar(c): caminables += 1
		print("alfombra %s: %d/%d celdas ocupadas, %d/%d caminables  (bloquea_paso=%s)"
			% [def.tamano_grilla, ocupadas, celdas.size(), caminables, celdas.size(), def.bloquea_paso])
		if ocupadas != celdas.size():
			print("FALLO: la alfombra no reserva todas sus celdas"); fallos += 1
		if caminables != celdas.size():
			print("FALLO: la alfombra bloquea el paso y no deberia"); fallos += 1

		# No se le pone una mesa encima.
		var inst3 := ItemInstance.new(); inst3.definicion_id = &"silla_madera"
		if Errores.ok(sala.colocar_objeto(inst3, ancla, 0)):
			print("FALLO: se pudo poner una silla sobre la alfombra"); fallos += 1

		# Y el A* la cruza.
		var r2 := grid.ruta(Vector2i(33, 35), Vector2i(38, 35))
		if r2.is_empty():
			print("FALLO: el A* no puede cruzar la alfombra"); fallos += 1
		else:
			print("el A* cruza la alfombra: %d pasos" % r2.size())

	# --- un mueble normal sigue bloqueando ---
	var inst4 := ItemInstance.new(); inst4.definicion_id = &"mesa"
	var lejos := Vector2i(39, 39)
	sala.colocar_objeto(inst4, lejos, 0)
	if grid.se_puede_caminar(lejos):
		print("FALLO: se puede caminar sobre una mesa"); fallos += 1
	else:
		print("una mesa sigue bloqueando")

	# Y al reves: el mismo objeto declarado como bloqueante vuelve a cortar el paso.
	def.bloquea_paso = true
	grid.recalcular_paredes()
	var celdas2 := grid.celdas_de(ancla, def.tamano_grilla, 0)
	var sigue := 0
	for c in celdas2:
		if grid.se_puede_caminar(c): sigue += 1
	print("misma alfombra con bloquea_paso=true: %d/%d caminables" % [sigue, celdas2.size()])
	if sigue != 0:
		print("FALLO: el flag no cambia nada"); fallos += 1

	print("OCUPAR VS BLOQUEAR: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
