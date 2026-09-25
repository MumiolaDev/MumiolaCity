extends Node

## Comprueba el navegador de salas y la barra de abajo, usados como los usaria
## el jugador: escribiendo un nombre, eligiendo una forma y apretando botones.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. Escribe en user://salas; ver test_servidor.
##
## El recorrido es el criterio de la etapa: crear una sala, amueblarla, salir
## del editor, irse a la plaza, volver, y que este igual. Ademas, lo que cuida
## que el sandbox no se vuelva un problema con otros jugadores: una sala ajena no
## se edita ni por boton ni por tecla, y no se levantan sus muebles.

var _fallos := 0


func _ready() -> void:
	for i in 3: await get_tree().process_frame
	GameManager.jugador_actual().set_process_unhandled_input(false)
	var nav : NavegadorUI = get_tree().root.find_child("NavegadorUI", true, false)
	var barra : BarraJuego = get_tree().root.find_child("BarraJuego", true, false)
	var ayuda : AyudaUI = get_tree().root.find_child("AyudaUI", true, false)
	if nav == null or barra == null:
		print("FALLO: falta el navegador o la barra"); get_tree().quit(); return

	await _probar_crear_y_volver(nav, barra)
	await _probar_sala_ajena(barra)
	await _probar_ventanas(nav, ayuda, barra)
	_probar_miniatura()

	print("NAVEGADOR: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _probar_crear_y_volver(nav : NavegadorUI, barra : BarraJuego) -> void:
	nav.abrir()
	await _esperar()
	var formas : ItemList = nav._formas
	_comprobar(formas.item_count == 5, "el navegador ofrece las cinco formas")
	_comprobar(nav._publicas.item_count >= 1 and nav._publicas.get_item_text(0).contains("(estas aca)"),
		"la plaza aparece, marcada como donde estas (%s)" % nav._publicas.get_item_text(0))
	_comprobar(nav._boton_crear.disabled, "sin nombre no se puede crear")

	nav._nombre_nueva.text = "Taller"
	nav._nombre_nueva.text_changed.emit("Taller")
	formas.select(2)
	_comprobar(not nav._boton_crear.disabled, "con nombre y forma, si")
	nav._boton_crear.pressed.emit()
	await _esperar_cambio()
	var sala := GameManager.sala_actual()
	_comprobar(sala.nombre_sala == "Taller" and sala.propietario_id == GameManager.perfil_id(),
		"crear lleva a la sala nueva, que es tuya")
	_comprobar(not nav.visible, "y cierra el navegador")

	var editar : Button = barra.get_node("%Editar")
	var guardar : Button = barra.get_node("%Guardar")
	_comprobar(not editar.disabled, "en tu sala se puede editar")
	editar.button_pressed = true
	await _esperar()
	_comprobar(GameManager.editando() and guardar.visible, "el boton entra al editor y muestra Guardar")

	sala.aplicar(OperacionSala.colocar(&"mesa", Vector2i(3, 3), 0))
	sala.aplicar(OperacionSala.colocar(&"banqueta", Vector2i(6, 3), 0))
	var antes := JSON.stringify(sala.to_dict().objetos)
	editar.button_pressed = false
	await _esperar()
	_comprobar(not GameManager.editando() and not guardar.visible, "Listo sale del editor")
	_comprobar(not sala.esta_sucia(), "y salir del editor guardo la sala")

	nav.abrir()
	await _esperar()
	var id := sala.id_sala
	_comprobar(nav._propias.item_count == 1, "la sala aparece en Mis salas")
	nav._ir(nav._publicas, 0)
	await _esperar_cambio()
	_comprobar(GameManager.sala_actual().id_sala == GameManager.SALA_INICIAL, "Ir lleva a la plaza")

	nav.abrir()
	await _esperar()
	nav._propias.select(0)
	nav._boton_ir_propia.pressed.emit()
	await _esperar_cambio()
	_comprobar(GameManager.sala_actual().id_sala == id, "y se vuelve al taller")
	_comprobar(JSON.stringify(GameManager.sala_actual().to_dict().objetos) == antes,
		"con los muebles donde quedaron")

	# No se borra la sala en la que estas.
	nav.abrir()
	await _esperar()
	nav._propias.select(0)
	Consola.limpiar()
	await nav._borrar_elegida()
	_comprobar(Consola.historial().size() == 1
		and Consola.historial()[0].texto == Errores.mensaje(Errores.Codigo.SALA_EN_USO),
		"borrar la sala donde estas se rechaza")
	nav.cerrar()


func _probar_sala_ajena(barra : BarraJuego) -> void:
	var local := ServidorLocal.new()
	var r := local.crear_sala("Casa de Otro", &"cuadrada_chica", &"otro_jugador")
	var doc : Dictionary = local.obtener_sala(r.id).doc
	(doc.objetos as Array).append({"item": "silla_madera", "celda": [4, 4], "rotacion": 0,
		"contenido": "", "contenido_cantidad": 0})
	local._escribir(r.id, doc)

	await GameManager.ir_a(r.id)
	var sala := GameManager.sala_actual()
	var editar : Button = barra.get_node("%Editar")
	_comprobar(sala.propietario_id == &"otro_jugador", "estas en la sala de otro")
	_comprobar(editar.disabled, "el boton Editar esta apagado")
	_comprobar(GameManager.alternar_modo() == Errores.Codigo.NO_ES_TUYO and not GameManager.editando(),
		"y la tecla tampoco entra al editor")

	var silla := sala.grid.objeto_en(Vector2i(4, 4))
	var levantar : InteractionBehavior = load("res://data/objetos/comportamientos/levantar.tres")
	InventoryManager.vaciar()
	if silla != null:
		silla.ejecutar(levantar, GameManager.jugador_actual())
		await _esperar()
	_comprobar(silla != null and is_instance_valid(silla) and sala.grid.objeto_en(Vector2i(4, 4)) == silla,
		"no se levantan los muebles ajenos")
	_comprobar(InventoryManager.cantidad_de(&"silla_madera") == 0, "ni terminan en tu mochila")

	await GameManager.ir_a(GameManager.SALA_INICIAL)
	local.borrar_sala(r.id, &"otro_jugador")


func _probar_ventanas(nav : NavegadorUI, ayuda : AyudaUI, barra : BarraJuego) -> void:
	barra.get_node("%Salas").pressed.emit()
	barra.get_node("%Ayuda").pressed.emit()
	await _esperar()
	_comprobar(nav.visible and ayuda.visible, "los botones abren sus ventanas")
	_apretar(KEY_ESCAPE)
	await _esperar()
	_comprobar(nav.visible and not ayuda.visible, "Esc cierra solo la de adelante")
	_apretar(KEY_ESCAPE)
	await _esperar()
	_comprobar(not nav.visible, "y otro Esc la siguiente")
	_apretar(KEY_N)
	await _esperar()
	_comprobar(nav.visible, "N abre el navegador")
	_apretar(KEY_N)
	await _esperar()
	_comprobar(not nav.visible, "y lo cierra")


func _probar_miniatura() -> void:
	var forma : Dictionary = ServidorLocal.new().plantillas()[0]
	var textura := NavegadorUI.miniatura(forma.estructura, forma.entrada)
	_comprobar(textura != null and textura.get_width() > 0, "cada forma tiene su miniatura")
	_comprobar(NavegadorUI.miniatura({}) == null, "una estructura vacia no dibuja nada")


func _apretar(tecla : Key) -> void:
	var e := InputEventKey.new()
	e.keycode = tecla
	e.pressed = true
	Input.parse_input_event(e)


func _esperar() -> void:
	for i in 3: await get_tree().process_frame


func _esperar_cambio() -> void:
	await get_tree().process_frame
	while GameManager.cambiando_de_sala():
		await get_tree().process_frame
	await _esperar()


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
