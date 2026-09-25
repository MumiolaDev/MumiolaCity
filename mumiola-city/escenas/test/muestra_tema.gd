extends Control

## Muestrario del tema: un control de cada tipo, para mirar el tema de un vistazo
## despues de regenerarlo.
##
## Se corre con F6 sobre muestra_tema.tscn. Con el argumento de usuario
## "--captura=<ruta.png>" guarda una captura y se cierra solo, que es como se
## verifica sin abrir el editor:
##
##     godot --path . --position 6000,6000 res://escenas/test/muestra_tema.tscn -- --captura=/tmp/tema.png
##
## Se arma en codigo y no en la escena porque lo que se quiere ver es el tema,
## no una composicion: agregar un control nuevo al muestrario es una linea.

func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("5f8a6a")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var ventana := _ventana_controles()
	add_child(ventana)
	ventana.abrir()
	ventana.ubicar(Vector2(24, 24))

	var paneles := _ventana_paneles()
	add_child(paneles)
	paneles.abrir()
	paneles.ubicar(Vector2(560, 24))

	add_child(_consola_de_muestra())

	var d := Dialogo.pedir_texto(self, "Crear sala", "Nombre de la sala nueva:", "Taller")
	d.ubicar(Vector2(800, 400))

	_capturar_si_se_pidio()


func _ventana_controles() -> Ventana:
	var ventana := Ventana.new()
	ventana.titulo = "Controles"
	ventana.custom_minimum_size = Vector2(500, 0)

	var pestanas := TabContainer.new()
	pestanas.custom_minimum_size = Vector2(0, 360)

	var basicos := VBoxContainer.new()
	basicos.name = "Basicos"
	basicos.add_theme_constant_override(&"separation", 10)
	var titulo := Label.new()
	titulo.text = "Un titulo grande"
	titulo.theme_type_variation = &"Titulo"
	basicos.add_child(titulo)
	var etiqueta := Label.new()
	etiqueta.text = "Texto comun: ¿Qué tal? áéíóú ñ 0123456789"
	basicos.add_child(etiqueta)

	var fila := HBoxContainer.new()
	for texto in ["Aceptar", "Cancelar"]:
		var b := Button.new()
		b.text = texto
		fila.add_child(b)
	var apagado := Button.new()
	apagado.text = "Apagado"
	apagado.disabled = true
	fila.add_child(apagado)
	var icono := Button.new()
	icono.theme_type_variation = &"BotonIcono"
	icono.icon = load("res://arte/sprites/UI/flat_x2/IconArrow01b.png")
	fila.add_child(icono)
	basicos.add_child(fila)

	var campo := LineEdit.new()
	campo.placeholder_text = "Escribi algo..."
	basicos.add_child(campo)

	var opciones := OptionButton.new()
	for o in ["Cuadrada chica", "En L", "Pasillo"]:
		opciones.add_item(o)
	basicos.add_child(opciones)

	var casilla := CheckBox.new()
	casilla.text = "Pantalla completa"
	casilla.button_pressed = true
	basicos.add_child(casilla)
	var interruptor := CheckButton.new()
	interruptor.text = "Mostrar debug"
	basicos.add_child(interruptor)

	var barra := ProgressBar.new()
	barra.value = 62
	basicos.add_child(barra)
	var deslizador := HSlider.new()
	deslizador.value = 40
	basicos.add_child(deslizador)
	pestanas.add_child(basicos)

	var lista := ItemList.new()
	lista.name = "Lista"
	for s in ["Plaza", "Casa de Diego", "Taller", "Cafe", "Jardin", "Biblioteca",
			"Sala 7", "Sala 8", "Sala 9", "Sala 10", "Sala 11", "Sala 12"]:
		lista.add_item(s)
	lista.select(1)
	pestanas.add_child(lista)

	ventana.add_child(pestanas)
	return ventana


func _ventana_paneles() -> Ventana:
	var ventana := Ventana.new()
	ventana.titulo = "Paneles"
	var fila := HBoxContainer.new()
	for variacion in [&"PanelAzul", &"PanelNaranja", &"Ranura"]:
		var p := PanelContainer.new()
		p.theme_type_variation = variacion
		p.custom_minimum_size = Vector2(110, 80)
		var l := Label.new()
		l.text = variacion
		p.add_child(l)
		fila.add_child(p)
	ventana.add_child(fila)
	return ventana


func _consola_de_muestra() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelConsola"
	panel.position = Vector2(12, 470)
	panel.custom_minimum_size = Vector2(460, 230)

	var columna := VBoxContainer.new()
	var filtros := HBoxContainer.new()
	for f in ["Todo", "Chat", "Sistema", "Debug"]:
		var b := Button.new()
		b.text = f
		b.toggle_mode = true
		b.button_pressed = f == "Todo"
		b.theme_type_variation = &"FiltroConsola"
		filtros.add_child(b)
	columna.add_child(filtros)

	var texto := RichTextLabel.new()
	texto.theme_type_variation = &"TextoConsola"
	texto.bbcode_enabled = true
	texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texto.text = ("[color=#ffc579]Diego:[/color] hola, alguien quiere cafe?\n"
		+ "[color=#9fd3ff]* Entraste a Plaza.[/color]\n"
		+ "[color=#ff8a7a]No se puede colocar ahi: la celda esta ocupada.[/color]\n"
		+ "[color=#9a9a9a][debug] ruta 14 celdas, 0.3 ms[/color]")
	columna.add_child(texto)

	var campo := LineEdit.new()
	campo.theme_type_variation = &"CampoConsola"
	campo.placeholder_text = "Enter para hablar, / para comandos"
	columna.add_child(campo)

	panel.add_child(columna)
	return panel


func _capturar_si_se_pidio() -> void:
	var ruta := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captura="):
			ruta = arg.trim_prefix("--captura=")
	if ruta == "":
		return
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ruta)
	print("muestra_tema: captura en ", ruta)
	get_tree().quit()
