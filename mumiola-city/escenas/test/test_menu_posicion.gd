extends Node

## Comprueba que el menu contextual aparezca junto al objeto y dentro de la
## pantalla, y no en una esquina fija.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## El bug que motivo esta prueba era invisible leyendo el codigo: ContextMenuUI
## es un PopupMenu, un PopupMenu es una Window y una Window es un Viewport, asi
## que get_viewport() devolvia el del propio menu. El limite de pantalla pasaba a
## ser el tamanio del menu y el recorte aplastaba cualquier posicion contra el
## origen.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var menu : ContextMenuUI = get_tree().root.find_child("ContextMenuUI", true, false)
	var jugador := GameManager.jugador_actual()
	var fallos := 0

	if menu == null:
		print("FALLO: no hay menu en el arbol"); get_tree().quit(); return

	var limite : Vector2 = get_viewport().get_visible_rect().size
	print("viewport: %s" % limite)

	var puestos : Array = []
	for celda in [Vector2i(3, 3), Vector2i(15, 8), Vector2i(8, 16)]:
		var inst := ItemInstance.new(); inst.definicion_id = &"silla_madera"
		if Errores.ok(sala.colocar_objeto(inst, celda, 0)):
			puestos.append(sala.grid.objeto_en(celda))
	await get_tree().process_frame

	var vistas : Array = []
	for obj in puestos:
		if not menu.mostrar_para(obj, jugador):
			print("FALLO: el menu no abrio"); fallos += 1; continue

		var esperado : Vector2 = sala.camara.unproject_position(obj.global_position)
		var donde : Vector2 = Vector2(menu.position)
		vistas.append(donde)
		var lejos : float = (donde - esperado).length()
		var entero : bool = (donde.x >= 0 and donde.y >= 0
			and donde.x + menu.size.x <= limite.x and donde.y + menu.size.y <= limite.y)
		print("  objeto en %s -> menu en %s  (a %.0f px, entero en pantalla: %s)"
			% [esperado.round(), donde, lejos, entero])
		if lejos > 60.0:
			print("  FALLO: el menu quedo a %.0f px del objeto" % lejos); fallos += 1
		if not entero:
			print("  FALLO: el menu se sale de la pantalla"); fallos += 1
		menu.hide()

	if vistas.size() >= 2 and vistas[0] == vistas[1]:
		print("FALLO: el menu abre siempre en el mismo lugar"); fallos += 1

	# Pegado al borde de abajo a la derecha: se corre para entrar entero.
	var region := sala.grid.region_usada()
	var esquina := region.position + region.size - Vector2i(2, 2)
	var inst2 := ItemInstance.new(); inst2.definicion_id = &"silla_madera"
	if Errores.ok(sala.colocar_objeto(inst2, esquina, 0)):
		await get_tree().process_frame
		var obj2 := sala.grid.objeto_en(esquina)
		if obj2 != null and menu.mostrar_para(obj2, jugador):
			var d : Vector2 = Vector2(menu.position)
			var entero2 : bool = d.x + menu.size.x <= limite.x and d.y + menu.size.y <= limite.y
			print("  pegado al borde %s -> menu en %s (%s), entero: %s"
				% [esquina, d, menu.size, entero2])
			if not entero2:
				print("  FALLO: no se recorto contra el borde"); fallos += 1

	print("MENU: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
