extends Node

## Comprueba que el clic que cierra el menu contextual no mande a caminar.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Dos trampas que esta prueba tuvo que aprender a esquivar, y las dos hacian que
## pasara o fallara por el motivo equivocado:
##
## Los clics se empujan con in_local_coords en true. Sin eso, push_input()
## transforma la posicion y el evento llega con coordenadas que no caen sobre
## ninguna celda: el personaje no se mueve, pero no por el guardia.
##
## Y hay que detenerlo entre caso y caso. Si no, el movimiento que sobra del clic
## anterior se lee como si el nuevo lo hubiera mandado a caminar.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var menu : ContextMenuUI = get_tree().root.find_child("ContextMenuUI", true, false)
	var jugador := GameManager.jugador_actual()
	var fallos := 0

	GameManager.descartar_clic()
	if not GameManager.clic_descartado():
		print("FALLO: no se consume en el mismo cuadro"); fallos += 1
	if GameManager.clic_descartado():
		print("FALLO: se consumio dos veces"); fallos += 1
	GameManager.descartar_clic()
	await get_tree().process_frame
	if GameManager.clic_descartado():
		print("FALLO: el descarte sobrevivio al cuadro"); fallos += 1
	print("guardia: se consume una sola vez y se vence al cuadro siguiente")

	var inst := ItemInstance.new(); inst.definicion_id = &"silla_madera"
	sala.colocar_objeto(inst, Vector2i(4, 4), 0)
	await get_tree().process_frame
	var obj := sala.grid.objeto_en(Vector2i(4, 4))

	var normal := await _medir(jugador, Vector2(300, 300), null, null)
	print("clic normal: se movio %.3f m" % normal)
	if normal < 0.1:
		print("FALLO: un clic normal no mueve al personaje, la prueba no vale"); fallos += 1

	var cancelando := await _medir(jugador, Vector2(900, 700), menu, obj)
	print("clic que cierra el menu: se movio %.3f m" % cancelando)
	if cancelando > 0.05:
		print("FALLO: el personaje salio caminando al cancelar el menu"); fallos += 1

	var despues := await _medir(jugador, Vector2(900, 700), null, null)
	print("clic siguiente: se movio %.3f m" % despues)
	if despues < 0.1:
		print("FALLO: el descarte se quedo pegado y bloquea los clics siguientes"); fallos += 1

	print("CLIC Y MENU: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()


## Deja al personaje quieto, opcionalmente abre y cierra el menu, clickea y mide.
func _medir(jugador : Node, donde : Vector2, menu : ContextMenuUI, obj : WorldObject) -> float:
	jugador.detener()
	for i in 3: await get_tree().physics_frame
	var antes : Vector3 = jugador.global_position

	if menu != null and obj != null:
		menu.mostrar_para(obj, jugador)
		menu.hide()

	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = donde
	get_viewport().push_input(e, true)

	await get_tree().process_frame
	for i in 25: await get_tree().physics_frame
	return (jugador.global_position - antes).length()
