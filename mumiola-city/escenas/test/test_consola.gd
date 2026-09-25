extends Node

## Comprueba la consola: el canal de mensajes, los comandos y la caja de chat.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Lo delicado que se mide: que los avisos viejos (GameManager.avisar) sigan
## llegando, ahora a la consola; que un comando que falla diga por que y como se
## usa; que el texto que escribe una persona no se interprete como BBCode en la
## pantalla de nadie; que el historial tenga techo; y que escribir en la caja no
## le mande teclas al mundo.

var _fallos := 0


func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var caja : ConsolaUI = get_tree().root.find_child("ConsolaUI", true, false)
	if caja == null:
		print("FALLO: no hay ConsolaUI en el mundo"); get_tree().quit(); return

	_probar_canal()
	_probar_comandos()
	await _probar_caja(caja)
	_probar_historial()

	print("CONSOLA: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _probar_canal() -> void:
	Consola.limpiar()
	GameManager.avisar("hola desde el juego")
	GameManager.avisar_error(Errores.Codigo.CELDA_OCUPADA)
	GameManager.avisar_error(Errores.Codigo.OK)
	var h := Consola.historial()
	_comprobar(h.size() == 2, "avisar y avisar_error llegan, y un OK no dice nada (%d)" % h.size())
	if h.size() == 2:
		_comprobar(h[0].canal == Consola.Canal.SISTEMA and h[1].canal == Consola.Canal.ERROR,
			"cada uno por su canal")
		_comprobar(h[1].texto == Errores.mensaje(Errores.Codigo.CELDA_OCUPADA),
			"el error trae el mensaje del codigo")

	Consola.limpiar()
	Consola.enviar("buenas")
	h = Consola.historial()
	_comprobar(h.size() == 1 and h[0].canal == Consola.Canal.CHAT, "sin barra es chat")
	if h.size() == 1:
		_comprobar(h[0].autor_nombre == GameManager.nombre_jugador() and h[0].autor_id != &"",
			"el chat dice quien hablo (%s, %s)" % [h[0].autor_id, h[0].autor_nombre])
	_comprobar(Consola.enviar("   ") == Errores.Codigo.OK and Consola.historial().size() == 1,
		"un mensaje en blanco no se manda")


func _probar_comandos() -> void:
	Consola.limpiar()
	_comprobar(Consola.enviar("/nada_de_nada") == Errores.Codigo.COMANDO_DESCONOCIDO,
		"un comando que no existe se rechaza")
	_comprobar(Consola.historial().size() == 1 and Consola.historial()[0].canal == Consola.Canal.ERROR,
		"y se dice por que")

	Consola.limpiar()
	_comprobar(Consola.enviar("/dar") == Errores.Codigo.USO_INCORRECTO, "/dar sin argumentos es mal uso")
	var linea : String = Consola.historial()[0].texto if Consola.historial().size() > 0 else ""
	_comprobar(linea.contains("/dar <item>"), "el rechazo muestra como se usa (%s)" % linea)

	InventoryManager.vaciar()
	_comprobar(Errores.ok(Consola.enviar("/DAR silla_madera 2")),
		"/dar funciona, con el nombre en mayusculas")
	_comprobar(InventoryManager.cantidad_de(&"silla_madera") == 2, "y pone dos sillas en la mochila")
	_comprobar(Consola.enviar("/dar no_existe") == Errores.Codigo.ITEM_DESCONOCIDO,
		"un item que no existe se rechaza")
	InventoryManager.vaciar()

	var llamadas := [0]
	Comandos.registrar(&"prueba_temporal", func(_a : PackedStringArray) -> void: llamadas[0] += 1, "x")
	_comprobar(Errores.ok(Consola.enviar("/prueba_temporal")) and llamadas[0] == 1,
		"un comando que no devuelve nada cuenta como OK")
	Comandos.quitar(&"prueba_temporal")

	var nombres : Array = Comandos.lista().map(func(c : Dictionary) -> String: return String(c.nombre))
	for esperado in ["ayuda", "limpiar", "debug", "inv", "dar", "editar", "guardar"]:
		_comprobar(esperado in nombres, "esta registrado /%s" % esperado)
	_comprobar(not Comandos.lista(false).any(func(c : Dictionary) -> bool: return c.debug),
		"la lista sin debug no trae comandos de debug")


func _probar_caja(caja : ConsolaUI) -> void:
	Consola.limpiar()
	Consola.chat(&"otro", "Otro [b]", "[img]res://icon.svg[/img] hola")
	await get_tree().process_frame
	var visible_texto := caja.get_node("%Texto") as RichTextLabel
	var parseado := visible_texto.get_parsed_text()
	_comprobar(parseado.contains("[img]res://icon.svg[/img]"),
		"el BBCode de un jugador se muestra como texto (%s)" % parseado.strip_edges())
	_comprobar(parseado.contains("Otro [b]:"), "tambien en el nombre")

	Consola.set_mostrar_debug(false)
	Consola.debug("linea secreta")
	await get_tree().process_frame
	_comprobar(not visible_texto.get_parsed_text().contains("linea secreta"), "debug oculto no se ve")
	Consola.set_mostrar_debug(true)
	await get_tree().process_frame
	_comprobar(visible_texto.get_parsed_text().contains("linea secreta"),
		"al prender debug aparece lo que ya se habia dicho")

	# Escribir en la caja no le manda la B al mundo.
	var modo_antes := GameManager.modo()
	caja.escribir()
	await get_tree().process_frame
	_comprobar(caja.escribiendo(), "Enter toma el teclado")
	var b := InputEventKey.new()
	b.keycode = KEY_B
	b.unicode = 98
	b.pressed = true
	Input.parse_input_event(b)
	await get_tree().process_frame
	await get_tree().process_frame
	_comprobar(GameManager.modo() == modo_antes, "con la caja tomada, B no cambia de modo")

	var campo := caja.get_node("%Campo") as LineEdit
	campo.text = "/limpiar"
	campo.text_submitted.emit(campo.text)
	await get_tree().process_frame
	_comprobar(not caja.escribiendo() and campo.text == "", "al mandar se vacia y suelta el teclado")
	_comprobar(Consola.historial().is_empty(), "el comando mandado desde la caja se ejecuto")


func _probar_historial() -> void:
	Consola.limpiar()
	for i in Consola.MAXIMO + 25:
		Consola.debug("linea %d" % i)
	var h := Consola.historial()
	_comprobar(h.size() == Consola.MAXIMO, "el historial tiene techo (%d)" % h.size())
	_comprobar(h[-1].texto == "linea %d" % (Consola.MAXIMO + 24), "y conserva lo mas nuevo")
	Consola.limpiar()


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
