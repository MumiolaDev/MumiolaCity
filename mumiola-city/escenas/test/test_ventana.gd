extends Node

## Comprueba los componentes de interfaz: Ventana y Dialogo.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. No usa nada del mundo, pero se cuelga de ahi como el resto para que
## haya una sola forma de correr pruebas.
##
## Lo que se mide es lo que se rompe sin avisar: que el contenido puesto en el
## editor termine debajo de la barra de titulo y no al lado; que una ventana
## ubicada a mano no se recentre al cuadro siguiente; que no se pueda perder
## fuera de la pantalla; y que un dialogo conteste una sola vez y se lleve su
## velo, porque un velo huerfano deja la interfaz entera sin clics.

var _fallos := 0


func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var capa := CanvasLayer.new()
	add_child(capa)

	await _probar_armado(capa)
	await _probar_ubicacion(capa)
	await _probar_dialogo(capa)

	print("VENTANA: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _probar_armado(capa : CanvasLayer) -> void:
	var v := Ventana.new()
	v.titulo = "Prueba"
	var contenido := Label.new()
	contenido.name = "Contenido"
	v.add_child(contenido)
	capa.add_child(v)

	_comprobar(contenido.get_parent() == v.cuerpo(), "el contenido quedo debajo del cuerpo")
	_comprobar(v.cuerpo().get_child(0).name == "BarraTitulo", "la barra de titulo va primero")

	var cerradas := [0]
	v.cerrada.connect(func() -> void: cerradas[0] += 1)
	v.abrir()
	_comprobar(v.visible, "abrir la muestra")
	v.cerrar()
	v.cerrar()
	_comprobar(not v.visible and cerradas[0] == 1, "cerrar dos veces avisa una sola")
	v.alternar()
	_comprobar(v.visible, "alternar la vuelve a abrir")
	v.queue_free()
	await get_tree().process_frame


func _probar_ubicacion(capa : CanvasLayer) -> void:
	var pantalla := get_viewport().get_visible_rect().size

	var centrada := Ventana.new()
	centrada.custom_minimum_size = Vector2(200, 100)
	capa.add_child(centrada)
	centrada.abrir()
	await get_tree().process_frame
	var centro := centrada.position + centrada.size / 2.0
	_comprobar(centro.distance_to(pantalla / 2.0) < 2.0,
		"la primera vez se abre centrada (%s)" % centro)

	var ubicada := Ventana.new()
	ubicada.custom_minimum_size = Vector2(200, 100)
	capa.add_child(ubicada)
	ubicada.abrir()
	ubicada.ubicar(Vector2(30, 40))
	await get_tree().process_frame
	await get_tree().process_frame
	_comprobar(ubicada.position == Vector2(30, 40),
		"ubicar gana al centrado diferido (%s)" % ubicada.position)

	ubicada.cerrar()
	ubicada.abrir()
	await get_tree().process_frame
	_comprobar(ubicada.position == Vector2(30, 40), "al reabrir esta donde la dejaste")

	ubicada.ubicar(Vector2(pantalla.x + 500, -300))
	_comprobar(ubicada.position.x < pantalla.x and ubicada.position.y >= 0,
		"no se puede ir fuera de la pantalla (%s)" % ubicada.position)

	centrada.queue_free()
	ubicada.queue_free()
	await get_tree().process_frame


func _probar_dialogo(capa : CanvasLayer) -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(raiz)

	var d := Dialogo.pedir_texto(raiz, "Nombre", "¿Como se llama?", "  Taller  ")
	var respuestas : Array = []
	d.respondido.connect(func(r : Dictionary) -> void: respuestas.append(r))
	_comprobar(raiz.get_child_count() == 1, "el dialogo trae su velo")

	d.responder(true)
	await get_tree().process_frame
	_comprobar(respuestas.size() == 1, "contesto una vez")
	if respuestas.size() == 1:
		_comprobar(respuestas[0].aceptado and respuestas[0].texto == "Taller",
			"devuelve el texto sin espacios (%s)" % [respuestas[0]])
	_comprobar(raiz.get_child_count() == 0, "el velo se fue con el dialogo")

	var c := Dialogo.confirmar(raiz, "Borrar", "¿Seguro?")
	var r2 : Array = []
	c.respondido.connect(func(r : Dictionary) -> void: r2.append(r))
	c.cerrar()
	await get_tree().process_frame
	_comprobar(r2.size() == 1 and not r2[0].aceptado, "la cruz cuenta como cancelar")
	_comprobar(raiz.get_child_count() == 0, "cancelar tambien se lleva el velo")
	raiz.queue_free()


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
