extends Node

## Comprueba que el clic que cierra el menu contextual no mande a caminar.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Lo importante es que reproduce el flujo real: se abre el menu y se deja que
## lo cierre el propio clic. La primera version lo cerraba a mano antes de
## clickear, y con eso pasaba sin comprobar nada — porque el orden real es al
## reves de lo que uno supone: _unhandled_input ve el clic **antes** de que el
## popup emita popup_hide.
##
## Otras dos trampas que tuvo que esquivar: los clics se empujan con
## in_local_coords en true, o push_input() transforma la posicion y el evento cae
## fuera de la grilla; y hay que detener al personaje entre caso y caso, o el
## movimiento que sobra del anterior se lee como si el nuevo lo hubiera mandado a
## caminar.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var menu : ContextMenuUI = get_tree().root.find_child("ContextMenuUI", true, false)
	var jugador := GameManager.jugador_actual()
	var fallos := 0

	if menu == null or jugador == null:
		print("FALLO: falta el menu o el jugador"); get_tree().quit(); return

	var inst := ItemInstance.new(); inst.definicion_id = &"silla_madera"
	sala.colocar_objeto(inst, Vector2i(4, 4), 0)
	await get_tree().process_frame
	var obj := sala.grid.objeto_en(Vector2i(4, 4))

	if GameManager.hay_menu_abierto():
		print("FALLO: arranca creyendo que hay un menu abierto"); fallos += 1

	# Control: sin menu, el clic camina.
	var normal := await _medir(jugador, Vector2(300, 300), null, null)
	print("clic normal: se movio %.3f m" % normal)
	if normal < 0.1:
		print("FALLO: un clic normal no mueve, la prueba no vale"); fallos += 1

	# El caso: con el menu abierto, el clic solo lo cierra.
	var cancelando := await _medir(jugador, Vector2(200, 900), menu, obj)
	print("clic con el menu abierto: se movio %.3f m" % cancelando)
	if cancelando > 0.05:
		print("FALLO: el personaje salio caminando al cancelar el menu"); fallos += 1
	if menu.visible:
		print("FALLO: el menu no se cerro"); fallos += 1
	if GameManager.hay_menu_abierto():
		print("FALLO: quedo contado un menu abierto que ya se cerro"); fallos += 1

	# Y el siguiente vuelve a caminar.
	var despues := await _medir(jugador, Vector2(200, 900), null, null)
	print("clic siguiente: se movio %.3f m" % despues)
	if despues < 0.1:
		print("FALLO: el guardia se quedo pegado"); fallos += 1

	print("CLIC Y MENU: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()


## Deja al personaje quieto, abre el menu si se le pasa uno, clickea y mide.
func _medir(jugador : Node, donde : Vector2, menu : ContextMenuUI, obj : WorldObject) -> float:
	jugador.detener()
	for i in 3: await get_tree().physics_frame

	if menu != null and obj != null:
		menu.mostrar_para(obj, jugador)
		await get_tree().process_frame

	var antes : Vector3 = jugador.global_position
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = donde
	get_viewport().push_input(e, true)

	await get_tree().process_frame
	for i in 25: await get_tree().physics_frame
	return (jugador.global_position - antes).length()
