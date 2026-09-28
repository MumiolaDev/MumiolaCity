extends Node

## Comprueba la ventana del personaje —la mochila y el perfil— y la vista de
## contenedor que usa, como las usaria el jugador: con los botones de la barra,
## con la tecla, eligiendo y arrastrando casillas.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. No escribe en disco.
##
## Se escribio antes que la ventana. Lo que fija:
##
##  - Que la barra abre la ventana en la pestana que corresponde a cada boton, y
##    que apretar el boton de la otra pestana cambia de pestana en vez de cerrar.
##  - Que la vista muestra un contenedor finito: todas sus casillas, los huecos
##    como huecos, cuantas estan ocupadas y cuanto pesa.
##  - Que se entera sola de los cambios, sin que nadie la refresque.
##  - Que arrastrar una casilla sobre otra mueve la cosa en el contenedor.
##  - Que la misma vista sirve para cualquier contenedor, no solo la mochila.

var _fallos := 0


func _ready() -> void:
	for i in 3: await get_tree().process_frame
	GameManager.jugador_actual().set_process_unhandled_input(false)
	var inv : InventoryUI = get_tree().root.find_child("InventoryUI", true, false)
	var barra : BarraJuego = get_tree().root.find_child("BarraJuego", true, false)
	if inv == null or barra == null:
		print("FALLO: falta la ventana del personaje o la barra"); get_tree().quit(); return
	InventoryManager.vaciar()

	await _probar_barra(inv, barra)
	await _probar_tecla(inv)
	await _probar_vista(inv)
	await _probar_eleccion(inv)
	await _probar_arrastre(inv)
	await _probar_perfil(inv)
	await _probar_reutilizable()

	InventoryManager.vaciar()
	print("INVENTARIO UI: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _probar_barra(inv : InventoryUI, barra : BarraJuego) -> void:
	var mochila : Button = barra.get_node("%Mochila")
	var yo : Button = barra.get_node("%Yo")
	_comprobar(not mochila.disabled and not yo.disabled, "la barra tiene Mochila y Yo, prendidos")
	_comprobar(not inv.visible, "la ventana arranca cerrada")

	mochila.pressed.emit()
	await _esperar()
	_comprobar(inv.visible and inv.pestana() == InventoryUI.Pestana.MOCHILA, "Mochila la abre en la mochila")
	mochila.pressed.emit()
	await _esperar()
	_comprobar(not inv.visible, "y otra vez la cierra")

	yo.pressed.emit()
	await _esperar()
	_comprobar(inv.visible and inv.pestana() == InventoryUI.Pestana.PERFIL, "Yo la abre en el perfil")
	mochila.pressed.emit()
	await _esperar()
	_comprobar(inv.visible and inv.pestana() == InventoryUI.Pestana.MOCHILA,
		"con el perfil abierto, Mochila cambia de pestana en vez de cerrar")
	mochila.pressed.emit()
	await _esperar()
	_comprobar(not inv.visible, "y en la suya, cierra")


func _probar_tecla(inv : InventoryUI) -> void:
	inv._unhandled_key_input(_tecla(KEY_I))
	await _esperar()
	_comprobar(inv.visible and inv.pestana() == InventoryUI.Pestana.MOCHILA, "I abre la mochila")
	inv._unhandled_key_input(_tecla(KEY_I))
	await _esperar()
	_comprobar(not inv.visible, "I la cierra")


func _probar_vista(inv : InventoryUI) -> void:
	InventoryManager.vaciar()
	InventoryManager.agregar(&"tomate", 5)
	inv.abrir_en(InventoryUI.Pestana.MOCHILA)
	await _esperar()

	var vista := inv.vista_mochila()
	_comprobar(vista != null and vista.contenedor() == InventoryManager.mochila, "la pestana muestra la mochila")
	_comprobar(vista.cantidad_casillas() == InventoryManager.CASILLAS,
		"con todas sus casillas: %d" % vista.cantidad_casillas())

	var tomate := ItemDatabase.obtener(&"tomate")
	var c0 := vista.casilla_vista(0)
	var c1 := vista.casilla_vista(1)
	_comprobar(c0.icono.texture == tomate.icono and c0.cantidad.text == "5", "la primera muestra el tomate y cuantos")
	_comprobar(c1.icono.texture == null and c1.cantidad.text == "", "la segunda es un hueco")
	_comprobar(vista._capacidad.text.contains("1/%d" % InventoryManager.CASILLAS),
		"dice cuantas casillas estan ocupadas: %s" % vista._capacidad.text)
	_comprobar(vista._peso.visible and is_equal_approx(vista._peso.max_value, InventoryManager.PESO_MAXIMO)
		and is_equal_approx(vista._peso.value, 1.0), "y cuanto pesa, contra el maximo")

	InventoryManager.agregar(&"mesa")
	await _esperar()
	var mesa := ItemDatabase.obtener(&"mesa")
	_comprobar(vista.casilla_vista(1).icono.texture == mesa.icono, "se entera sola de lo que entra")
	_comprobar(vista.casilla_vista(1).cantidad.text == "", "y una unidad sola no lleva numero")
	_comprobar(vista._capacidad.text.contains("2/%d" % InventoryManager.CASILLAS), "la cuenta se actualiza")


func _probar_eleccion(inv : InventoryUI) -> void:
	var vista := inv.vista_mochila()
	var elegidas : Array[int] = []
	vista.casilla_elegida.connect(func(i : int) -> void: elegidas.append(i))

	vista.elegir(1)
	_comprobar(vista.elegida() == 1 and elegidas == [1], "elegir una casilla avisa cual")
	_comprobar(vista._detalle_nombre.text == ItemDatabase.obtener(&"mesa").nombre,
		"y el detalle muestra que es: %s" % vista._detalle_nombre.text)

	vista.elegir(5)
	_comprobar(vista.elegida() == -1 and vista._detalle_nombre.text == "", "un hueco no se elige")

	vista.elegir(1)
	InventoryManager.quitar(&"mesa")
	await _esperar()
	_comprobar(vista.elegida() == -1 and vista._detalle_nombre.text == "",
		"si lo elegido se va, la eleccion se suelta")


func _probar_arrastre(inv : InventoryUI) -> void:
	var vista := inv.vista_mochila()
	InventoryManager.vaciar()
	InventoryManager.agregar(&"tomate", 5)
	InventoryManager.agregar(&"mesa")
	await _esperar()

	_comprobar(vista.casilla_vista(3).datos_de_arrastre() == null, "un hueco no se arrastra")
	var datos = vista.casilla_vista(1).datos_de_arrastre()
	_comprobar(datos != null, "una casilla con algo si")
	var destino := vista.casilla_vista(7)
	_comprobar(destino._can_drop_data(Vector2.ZERO, datos), "y se puede soltar en otra")
	destino._drop_data(Vector2.ZERO, datos)
	await _esperar()
	var mochila := InventoryManager.mochila
	_comprobar(mochila.casilla(1) == null and mochila.casilla(7) != null
		and mochila.casilla(7).definicion_id == &"mesa", "soltarla mueve la mesa en la mochila")
	_comprobar(vista.casilla_vista(7).icono.texture == ItemDatabase.obtener(&"mesa").icono,
		"y la vista la muestra en su lugar nuevo")

	var ajeno := Contenedor.new(4)
	ajeno.agregar(&"maceta")
	var otra := VistaContenedor.new()
	add_child(otra)
	otra.mostrar(ajeno)
	await _esperar()
	var de_otro = otra.casilla_vista(0).datos_de_arrastre()
	_comprobar(de_otro != null and not destino._can_drop_data(Vector2.ZERO, de_otro),
		"lo de otro contenedor todavia no se suelta en la mochila")
	otra.queue_free()


func _probar_perfil(inv : InventoryUI) -> void:
	inv.abrir_en(InventoryUI.Pestana.PERFIL)
	await _esperar()
	_comprobar(inv.titulo == GameManager.nombre_jugador(), "la ventana lleva el nombre del jugador: %s" % inv.titulo)

	var textos := _textos_de(inv.vista_perfil())
	_comprobar(textos.contains(GameManager.nombre_jugador()), "el perfil dice como se llama")
	var sala := GameManager.sala_actual()
	_comprobar(textos.contains(sala.nombre_sala), "y donde esta: %s" % sala.nombre_sala)
	inv.cerrar()


func _probar_reutilizable() -> void:
	var alacena := Contenedor.new(6, 0.0, "Alacena")
	alacena.agregar(&"frasco", 2)
	var vista := VistaContenedor.new()
	add_child(vista)
	vista.mostrar(alacena)
	await _esperar()

	_comprobar(vista.cantidad_casillas() == 6, "otra vista muestra las 6 casillas de una alacena")
	var frasco := ItemDatabase.obtener(&"frasco")
	_comprobar(vista.casilla_vista(0).icono.texture == frasco.icono
		and vista.casilla_vista(1).icono.texture == frasco.icono, "con sus dos frascos, uno por casilla")
	_comprobar(not vista._peso.visible, "sin limite de peso no hay barra de peso")
	_comprobar(vista._capacidad.text.contains("2/6"), "pero si la cuenta de casillas")

	var cajon := Contenedor.new(3)
	vista.mostrar(cajon)
	alacena.agregar(&"frasco")
	await _esperar()
	_comprobar(vista.cantidad_casillas() == 3 and vista.casilla_vista(0).icono.texture == null,
		"mostrar otro contenedor suelta el anterior")
	vista.queue_free()


## Junta el texto de todas las etiquetas debajo de un nodo.
func _textos_de(nodo : Node) -> String:
	var partes : Array[String] = []
	for hijo in nodo.find_children("*", "Label", true, false):
		partes.append((hijo as Label).text)
	return "\n".join(partes)


func _tecla(codigo : Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.pressed = true
	return e


func _esperar() -> void:
	for i in 3: await get_tree().process_frame


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
