extends Node

## Comprueba que absolutamente todo objeto colocado responda a "mirar".
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. Coloca los 45 colocables, comprueba que cada uno ofrezca el verbo,
## que devuelva un texto no vacio y que ejecutarlo funcione, mas el caso de un
## objeto sin definicion en el catalogo.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var jugador := GameManager.jugador_actual()
	var fallos := 0
	var puestos := 0

	var celdas : Array[Vector2i] = []
	for x in range(2, 20):
		for z in range(2, 20):
			var c := Vector2i(x, z)
			if Errores.ok(sala.grid.motivo_bloqueo(c, Vector2i.ONE)):
				celdas.append(c)

	var sin_mirar : Array[String] = []
	var sin_texto : Array[String] = []
	var muestras : Array[String] = []

	var siguiente := 0
	for def in ItemDatabase.colocables():
		# Avanzar de celda pase lo que pase: si una colocacion falla y no se
		# avanza, la siguiente reintenta la misma celda, que ya quedo ocupada, y
		# a partir de ahi fallan todas.
		var celda := IsoGrid.SIN_CELDA
		while siguiente < celdas.size():
			var c : Vector2i = celdas[siguiente]
			siguiente += 1
			if Errores.ok(sala.colocar_objeto(_instancia(def.id), c, 0)):
				celda = c
				break
		if celda == IsoGrid.SIN_CELDA:
			print("no se pudo colocar %s en ninguna celda" % def.id)
			continue
		puestos += 1
		var obj := sala.grid.objeto_en(celda)
		if obj == null:
			continue

		var verbos := obj.verbos_disponibles(jugador)
		var tiene := false
		for v in verbos:
			if v.verbo == &"mirar":
				tiene = true
		if not tiene:
			sin_mirar.append(String(def.id))
			continue

		var texto : String = WorldObject.MIRAR.texto_de(obj)
		if texto.strip_edges() == "":
			sin_texto.append(String(def.id))
		if muestras.size() < 4:
			muestras.append(texto)

		# Y que ejecutarlo de verdad funcione.
		if not obj.ejecutar(WorldObject.MIRAR, jugador):
			print("FALLO: ejecutar mirar sobre %s devolvio false" % def.id); fallos += 1

	print("objetos colocados: %d" % puestos)
	print("sin el verbo mirar: %d %s" % [sin_mirar.size(), sin_mirar])
	print("con texto vacio: %d %s" % [sin_texto.size(), sin_texto])
	for m in muestras:
		print("   ejemplo: %s" % m)
	if sin_mirar.size() > 0 or sin_texto.size() > 0:
		fallos += 1

	# Un objeto sin definicion tambien tiene que contestar algo.
	var suelto := WorldObject.new()
	suelto.name = "MesadaPublica"
	suelto.instancia = null
	var texto_suelto : String = WorldObject.MIRAR.texto_de(suelto)
	print("sin definicion responde: '%s'" % texto_suelto)
	if texto_suelto.strip_edges() == "":
		print("FALLO: un objeto sin definicion no contesta nada"); fallos += 1
	suelto.free()

	print("MIRAR: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()

func _instancia(id : StringName) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.definicion_id = id
	return inst
