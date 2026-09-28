extends Node

## Comprueba colocar desde la mochila jugando: el verbo que cierra el circulo de
## levantar.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. No escribe en disco.
##
## Se escribio antes que ColocadorJuego. Lo que fija:
##
##  - Que solo se empieza con algo colocable, jugando, en una sala que se puede
##    editar; y que cada rechazo dice por que.
##  - Que colocar pasa por RoomController.aplicar() y no entra al historial de
##    deshacer del editor, igual que levantar.
##  - Que la cosa sale de la mochila solo si queda en la sala: un rechazo la deja
##    en su casilla, y de una pila sale una unidad y la pila no se mueve.
##  - Que lo que tiene estado llega servido a la sala, y que girar se respeta.
##  - Que no pierde de vista lo que se esta colocando si se reordena la mochila,
##    y que se suelta solo si eso desaparece.
##  - Que el clic que coloca no manda a caminar al personaje, y que Esc y el clic
##    derecho cancelan sin hacer nada mas.
##  - Que la ventana de la mochila ofrece Colocar solo cuando se puede.

var _fallos := 0


func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var jugador := GameManager.jugador_actual()
	jugador.set_process_unhandled_input(false)
	var colocador : ColocadorJuego = get_tree().root.find_child("ColocadorJuego", true, false)
	var inv : InventoryUI = get_tree().root.find_child("InventoryUI", true, false)
	if colocador == null or inv == null:
		print("FALLO: falta el colocador o la ventana del personaje"); get_tree().quit(); return
	InventoryManager.vaciar()

	await _probar_empezar(colocador, sala)
	await _probar_colocar(colocador, sala)
	await _probar_estado_y_giro(colocador, sala)
	await _probar_seguimiento(colocador, sala)
	await _probar_entrada(colocador, sala, jugador)
	await _probar_boton(colocador, inv)

	InventoryManager.vaciar()
	print("COLOCAR MOCHILA: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _probar_empezar(c : ColocadorJuego, sala : RoomController) -> void:
	_comprobar(c.empezar(0) == Errores.Codigo.NO_TIENE_ITEM and not c.activo(),
		"con la casilla vacia no hay nada que colocar")

	InventoryManager.agregar(&"semilla_tomate")
	_comprobar(c.empezar(0) == Errores.Codigo.NO_COLOCABLE and not c.activo(),
		"una semilla no se coloca en el piso")

	InventoryManager.vaciar()
	InventoryManager.agregar(&"mesa")
	_comprobar(Errores.ok(c.empezar(0)) and c.activo(), "una mesa si")
	c.cancelar()
	_comprobar(not c.activo(), "cancelar suelta lo que se estaba colocando")

	GameManager.cambiar_modo(GameManager.Modo.EDITANDO)
	_comprobar(c.empezar(0) == Errores.Codigo.EDITANDO and not c.activo(),
		"editando, colocar es del editor")
	GameManager.cambiar_modo(GameManager.Modo.JUGANDO)
	c.empezar(0)
	GameManager.cambiar_modo(GameManager.Modo.EDITANDO)
	_comprobar(not c.activo(), "entrar al editor suelta lo que se estaba colocando")
	GameManager.cambiar_modo(GameManager.Modo.JUGANDO)

	var duenio := sala.propietario_id
	sala.propietario_id = &"otro_jugador"
	_comprobar(c.empezar(0) == Errores.Codigo.SIN_PERMISO and not c.activo(),
		"en la sala de otro no se coloca nada")
	sala.propietario_id = duenio


func _probar_colocar(c : ColocadorJuego, sala : RoomController) -> void:
	InventoryManager.vaciar()
	InventoryManager.agregar(&"tomate", 3)
	InventoryManager.agregar(&"mesa")
	var mesa := ItemDatabase.obtener(&"mesa")
	var a := _celda_libre(sala, mesa.tamano_grilla)
	var podia_deshacer := sala.puede_deshacer()

	c.empezar(1)
	_comprobar(Errores.ok(c.colocar_en(a)), "colocar la mesa en una celda libre")
	var obj := sala.grid.objeto_en(a)
	_comprobar(obj != null and obj.definicion() == mesa, "la mesa queda en la sala")
	_comprobar(InventoryManager.cantidad_de(&"mesa") == 0 and InventoryManager.mochila.casilla(1) == null,
		"y sale de la mochila")
	_comprobar(not c.activo(), "colocar una vez termina")
	_comprobar(sala.puede_deshacer() == podia_deshacer, "y no entra al historial del editor")

	InventoryManager.agregar(&"maceta")
	var indice := _indice_de(&"maceta")
	c.empezar(indice)
	_comprobar(c.colocar_en(a) == Errores.Codigo.CELDA_OCUPADA, "sobre la mesa no se puede")
	_comprobar(_es(indice, &"maceta", 1), "y la maceta sigue en su casilla")
	_comprobar(c.activo(), "y se puede seguir intentando en otro lado")
	c.cancelar()

	var b := _celda_libre(sala, Vector2i.ONE)
	c.empezar(0)
	_comprobar(Errores.ok(c.colocar_en(b)), "colocar un tomate de la pila")
	_comprobar(_es(0, &"tomate", 2), "sale uno y la pila se queda en su casilla")
	var tomate := sala.grid.objeto_en(b)
	_comprobar(tomate != null and tomate.definicion().id == &"tomate", "y el tomate queda en la sala")


func _probar_estado_y_giro(c : ColocadorJuego, sala : RoomController) -> void:
	InventoryManager.vaciar()
	var plato := ItemInstance.new()
	plato.definicion_id = &"plato"
	plato.contenido_id = &"guiso"
	plato.contenido_cantidad = 1
	InventoryManager.agregar_instancia(plato)
	var d := _celda_libre(sala, Vector2i.ONE)
	c.empezar(0)
	c.colocar_en(d)
	var obj := sala.grid.objeto_en(d)
	_comprobar(obj != null and obj.instancia != null and obj.instancia.contenido_id == &"guiso"
		and obj.instancia.contenido_cantidad == 1, "un plato servido llega servido")

	InventoryManager.agregar(&"silla_madera")
	var e := _celda_libre(sala, Vector2i.ONE)
	c.empezar(0)
	c.rotar()
	_comprobar(c.rotacion() == 1, "girar suma un cuarto de vuelta")
	c.colocar_en(e)
	var silla := sala.grid.objeto_en(e)
	_comprobar(silla != null and silla.rotacion_grilla == 1, "y la silla queda girada")


func _probar_seguimiento(c : ColocadorJuego, sala : RoomController) -> void:
	InventoryManager.vaciar()
	InventoryManager.agregar(&"tomate", 5)
	InventoryManager.agregar(&"maceta")
	c.empezar(1)
	InventoryManager.mochila.mover(1, 30)
	var f := _celda_libre(sala, Vector2i.ONE)
	_comprobar(Errores.ok(c.colocar_en(f)), "reordenar la mochila mientras se coloca no la pierde")
	_comprobar(InventoryManager.mochila.casilla(30) == null and sala.grid.objeto_en(f) != null,
		"coloca la maceta que se movio de casilla")

	InventoryManager.agregar(&"lampara_mesa")
	c.empezar(_indice_de(&"lampara_mesa"))
	InventoryManager.quitar(&"lampara_mesa")
	await get_tree().process_frame
	_comprobar(not c.activo(), "si lo que se colocaba desaparece de la mochila, se suelta")
	var g := _celda_libre(sala, Vector2i.ONE)
	_comprobar(c.colocar_en(g) == Errores.Codigo.NO_TIENE_ITEM and sala.grid.objeto_en(g) == null,
		"y ya no coloca nada")


func _probar_entrada(c : ColocadorJuego, sala : RoomController, jugador : PersonajeControlador) -> void:
	InventoryManager.vaciar()
	InventoryManager.agregar(&"maceta", 3)
	var pausa : Control = get_tree().root.find_child("MenuPausa", true, false)

	c.empezar(0)
	get_viewport().push_input(_tecla(KEY_ESCAPE))
	await _esperar()
	_comprobar(not c.activo(), "Esc cancela")
	_comprobar(pausa == null or not pausa.visible, "y no abre el menu de pausa")

	c.empezar(0)
	get_viewport().push_input(_tecla(KEY_R))
	_comprobar(c.rotacion() == 1, "R gira")
	get_viewport().push_input(_boton(MOUSE_BUTTON_RIGHT, Vector2(640, 360)))
	await _esperar()
	_comprobar(not c.activo(), "el clic derecho cancela")

	var h := _celda_libre(sala, Vector2i.ONE, true)
	var punto := sala.camara.unproject_position(sala.grid.centro_de(h, Vector2i.ONE, 0))
	if sala.grid.celda_bajo_puntero(sala.camara, punto) != h:
		_comprobar(false, "no se encontro en pantalla una celda libre para clickear")
		return
	jugador.set_process_unhandled_input(true)
	jugador.detener()
	c.empezar(0)
	# En coordenadas del viewport, que son las de unproject_position(): sin eso,
	# push_input() las toma como de la ventana y las estira, y en headless la
	# ventana y el viewport no miden lo mismo.
	get_viewport().push_input(_boton(MOUSE_BUTTON_LEFT, punto), true)
	get_viewport().push_input(_boton(MOUSE_BUTTON_LEFT, punto, false), true)
	await _esperar()
	var obj := sala.grid.objeto_en(h)
	_comprobar(obj != null and obj.definicion().id == &"maceta", "el clic izquierdo coloca donde apunta")
	_comprobar(jugador._ruta.is_empty(), "y el personaje no sale caminando hacia ahi")

	# El contraste, para que lo de arriba no pase de casualidad: sin nada que
	# colocar, el mismo clic sobre una celda libre si lo hace caminar.
	var libre := _celda_libre(sala, Vector2i.ONE, true)
	var otro_punto := sala.camara.unproject_position(sala.grid.centro_de(libre, Vector2i.ONE, 0))
	get_viewport().push_input(_boton(MOUSE_BUTTON_LEFT, otro_punto), true)
	get_viewport().push_input(_boton(MOUSE_BUTTON_LEFT, otro_punto, false), true)
	await _esperar()
	_comprobar(not jugador._ruta.is_empty(), "sin colocar nada, el mismo clic si lo hace caminar")
	jugador.detener()
	jugador.set_process_unhandled_input(false)


func _probar_boton(c : ColocadorJuego, inv : InventoryUI) -> void:
	InventoryManager.vaciar()
	InventoryManager.agregar(&"mesa")
	InventoryManager.agregar(&"semilla_tomate")
	inv.abrir_en(InventoryUI.Pestana.MOCHILA)
	await _esperar()
	var vista := inv.vista_mochila()
	var colocar : Button = inv._boton_colocar

	vista.elegir(-1)
	_comprobar(colocar.disabled, "sin nada elegido, Colocar esta apagado")
	vista.elegir(1)
	_comprobar(colocar.disabled, "con una semilla elegida tambien")
	vista.elegir(0)
	_comprobar(not colocar.disabled, "con la mesa elegida se prende")
	colocar.pressed.emit()
	await _esperar()
	_comprobar(c.activo(), "y apretarlo empieza a colocar")
	c.cancelar()

	vista.casilla_activada.emit(0)
	await _esperar()
	_comprobar(c.activo(), "el doble clic en la mesa tambien")
	c.cancelar()

	GameManager.cambiar_modo(GameManager.Modo.EDITANDO)
	await _esperar()
	_comprobar(colocar.disabled, "editando, Colocar se apaga")
	GameManager.cambiar_modo(GameManager.Modo.JUGANDO)
	await _esperar()
	_comprobar(not colocar.disabled, "y vuelve al salir del editor")
	inv.cerrar()


## Busca una celda de suelo donde entre algo de ese tamano, cerca de la entrada
## y sin el personaje encima. Con en_pantalla, que ademas se vea.
func _celda_libre(sala : RoomController, size : Vector2i, en_pantalla : bool = false) -> Vector2i:
	var parado := sala.grid.mundo_a_celda(GameManager.jugador_actual().global_position)
	var candidatas := sala.grid.celdas_pintadas(CatalogoPiezas.SUELO)
	candidatas.sort_custom(func(x : Vector2i, y : Vector2i) -> bool:
		return (x - sala.celda_entrada).length_squared() < (y - sala.celda_entrada).length_squared())
	var pantalla := get_viewport().get_visible_rect().grow(-120)
	for celda in candidatas:
		if (celda - sala.celda_entrada).length() < 2.0:
			continue
		if not Errores.ok(sala.grid.motivo_bloqueo(celda, size, 0)):
			continue
		if parado in sala.grid.celdas_de(celda, size, 0):
			continue
		if en_pantalla and not pantalla.has_point(sala.camara.unproject_position(sala.grid.centro_de(celda, size, 0))):
			continue
		return celda
	return IsoGrid.SIN_CELDA


func _indice_de(id : StringName) -> int:
	for i in InventoryManager.mochila.casillas():
		var s := InventoryManager.mochila.casilla(i)
		if s != null and s.definicion_id == id:
			return i
	return -1


func _es(indice : int, id : StringName, cantidad : int) -> bool:
	var s := InventoryManager.mochila.casilla(indice)
	return s != null and s.definicion_id == id and s.cantidad == cantidad


func _tecla(codigo : Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.pressed = true
	return e


func _boton(cual : MouseButton, punto : Vector2, apretado : bool = true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = cual
	e.position = punto
	e.global_position = punto
	e.pressed = apretado
	return e


func _esperar() -> void:
	for i in 3: await get_tree().process_frame


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
