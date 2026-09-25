@tool
extends RefCounted

## Arma el Theme de la interfaz a partir de los sprites del pack Flat.
##
## Vive aparte de GenerarTema.gd, que es solo el boton para correrlo desde el
## editor, para poder construirlo tambien sin editor: un EditorScript no se puede
## instanciar fuera de el, y esto hay que poder regenerarlo en una copia headless
## del proyecto.
##
## Los sprites vienen ya escalados x2 (herramientas/escalar_sprites_ui.py), asi
## que los margenes de textura se escriben en pixeles del sprite original y se
## multiplican por ESCALA al armar la caja. Leer "3" y buscar tres pixeles en el
## PNG del pack es mas facil que leer "6" y acordarse de dividir. Ver _caja().
##
## Es idempotente: volver a correrlo pisa el tema entero. Lo que se retoque a
## mano en tema.tres se pierde, y es intencional — igual que el catalogo, el tema
## tiene una sola fuente, y es este archivo.

const RUTA_TEMA := "res://ui/tema/tema.tres"
const DIR_SPRITES := "res://arte/sprites/UI/flat_x2/"
const FUENTE_UI := "res://ui/fuentes/PixelifySans.ttf"
const FUENTE_CONSOLA := "res://ui/fuentes/VT323-Regular.ttf"
const ESCALA := 2

## La paleta del pack, sacada de los sprites. Se exponen para que la interfaz
## que colorea texto a mano (la consola, por canal) no invente tonos nuevos.
const CREMA := Color("fffdf5")
const CANELA := Color("ffc579")
const TINTA := Color("2b2622")
const TINTA_SUAVE := Color("6b6258")
const GRIS_CLARO := Color("dfe5e9")
const GRIS := Color("adb7c4")
const GRIS_OSCURO := Color("808ba1")
const AZUL := Color("267ae9")
const NARANJA := Color("ffa61f")

const TAMANO_FUENTE := 16
const TAMANO_FUENTE_CONSOLA := 20
const TAMANO_TITULO := 24


## Construye el tema y lo guarda. Devuelve el error de guardado.
static func guardar() -> Error:
	DirAccess.make_dir_recursive_absolute(RUTA_TEMA.get_base_dir())
	var tema := construir()
	var error := ResourceSaver.save(tema, RUTA_TEMA)
	if error != OK:
		push_error("ConstructorTema: no se pudo guardar %s (%d)." % [RUTA_TEMA, error])
	elif not FileAccess.file_exists(RUTA_TEMA):
		# La leccion del importador, que reporto 52 guardados y escribio uno.
		push_error("ConstructorTema: se guardo %s sin error pero el archivo no existe." % RUTA_TEMA)
		return ERR_FILE_CANT_WRITE
	return error


## Construye el tema completo en memoria.
static func construir() -> Theme:
	var tema := Theme.new()
	tema.default_font = load(FUENTE_UI)
	tema.default_font_size = TAMANO_FUENTE

	_paneles(tema)
	_botones(tema)
	_textos(tema)
	_campos(tema)
	_pestanas(tema)
	_listas(tema)
	_barras(tema)
	_menus(tema)
	_casillas(tema)
	_ventana(tema)
	_consola(tema)
	return tema


# --- Por tipo de control ---------------------------------------------------------


static func _paneles(tema : Theme) -> void:
	var gris := _caja("Frame01a", [4, 4, 4, 4], [10, 10, 10, 10])
	tema.set_stylebox(&"panel", &"Panel", gris)
	tema.set_stylebox(&"panel", &"PanelContainer", gris)

	# Variaciones por color. Se usan con theme_type_variation en el inspector.
	_variacion(tema, &"PanelAzul", &"PanelContainer")
	tema.set_stylebox(&"panel", &"PanelAzul", _caja("Frame02a", [4, 4, 4, 4], [10, 10, 10, 10]))
	_variacion(tema, &"PanelNaranja", &"PanelContainer")
	tema.set_stylebox(&"panel", &"PanelNaranja", _caja("Frame03a", [4, 4, 4, 4], [10, 10, 10, 10]))

	# Un hueco hundido dentro de un panel: donde van listas, slots y contenido.
	_variacion(tema, &"Ranura", &"PanelContainer")
	tema.set_stylebox(&"panel", &"Ranura", _caja("FrameSlot01a", [3, 3, 3, 3], [6, 6, 6, 6]))


static func _botones(tema : Theme) -> void:
	# Los cuatro sprites son la misma tecla en cuatro alturas: _4 levantada, _1
	# hundida. El borde transparente de arriba crece a medida que baja, asi que
	# con los margenes de cada uno el texto baja solo al apretar, sin codigo.
	var normal := _caja("Button01a_3", [3, 4, 3, 7], [10, -1, 10, -1])
	var encima := _caja("Button01a_4", [3, 3, 3, 8], [10, -1, 10, -1])
	var apretado := _caja("Button01a_1", [3, 7, 3, 5], [10, -1, 10, -1])
	var apagado := _caja("Button01a_2", [3, 6, 3, 5], [10, -1, 10, -1])
	apagado.modulate_color = Color(0.8, 0.8, 0.8, 0.7)

	for tipo in [&"Button", &"OptionButton", &"MenuButton"]:
		tema.set_stylebox(&"normal", tipo, normal)
		tema.set_stylebox(&"hover", tipo, encima)
		tema.set_stylebox(&"pressed", tipo, apretado)
		tema.set_stylebox(&"hover_pressed", tipo, apretado)
		tema.set_stylebox(&"disabled", tipo, apagado)
		tema.set_stylebox(&"focus", tipo, StyleBoxEmpty.new())
		tema.set_color(&"font_color", tipo, TINTA)
		tema.set_color(&"font_hover_color", tipo, TINTA)
		tema.set_color(&"font_pressed_color", tipo, TINTA)
		tema.set_color(&"font_hover_pressed_color", tipo, TINTA)
		tema.set_color(&"font_focus_color", tipo, TINTA)
		tema.set_color(&"font_disabled_color", tipo, TINTA_SUAVE)
		tema.set_color(&"icon_normal_color", tipo, Color.WHITE)

	tema.set_icon(&"arrow", &"OptionButton", _textura("IconDropdown01a"))

	# Un boton cuadrado para las barras de herramientas: mismo sprite, sin el
	# relleno lateral que necesita el texto.
	_variacion(tema, &"BotonIcono", &"Button")
	for estado in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var caja : StyleBoxTexture = tema.get_stylebox(estado, &"Button").duplicate()
		caja.content_margin_left = 4 * ESCALA
		caja.content_margin_right = 4 * ESCALA
		tema.set_stylebox(estado, &"BotonIcono", caja)

	# La cruz de cerrar, que ya trae su propio marco dibujado.
	_variacion(tema, &"BotonCerrar", &"Button")
	var vacia := StyleBoxEmpty.new()
	for estado in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		tema.set_stylebox(estado, &"BotonCerrar", vacia)
	tema.set_color(&"icon_hover_color", &"BotonCerrar", Color(1.15, 1.15, 1.15))
	tema.set_color(&"icon_pressed_color", &"BotonCerrar", Color(0.8, 0.8, 0.8))


static func _textos(tema : Theme) -> void:
	tema.set_color(&"font_color", &"Label", TINTA)

	_variacion(tema, &"Titulo", &"Label")
	tema.set_font_size(&"font_size", &"Titulo", TAMANO_TITULO)

	# Texto sobre fondo oscuro o sobre el mundo: claro y con contorno, para que
	# se lea igual encima de un piso blanco que de uno negro.
	_variacion(tema, &"TextoClaro", &"Label")
	tema.set_color(&"font_color", &"TextoClaro", CREMA)
	tema.set_color(&"font_outline_color", &"TextoClaro", TINTA)
	tema.set_constant(&"outline_size", &"TextoClaro", 4)

	tema.set_color(&"default_color", &"RichTextLabel", TINTA)


static func _campos(tema : Theme) -> void:
	var campo := _caja("InputField01a", [2, 2, 2, 4], [8, 6, 8, 8])
	tema.set_stylebox(&"normal", &"LineEdit", campo)
	tema.set_stylebox(&"read_only", &"LineEdit", campo)
	tema.set_stylebox(&"focus", &"LineEdit", StyleBoxEmpty.new())
	tema.set_color(&"font_color", &"LineEdit", TINTA)
	tema.set_color(&"font_placeholder_color", &"LineEdit", TINTA_SUAVE)
	tema.set_color(&"caret_color", &"LineEdit", TINTA)
	tema.set_color(&"selection_color", &"LineEdit", Color(CANELA, 0.6))

	tema.set_stylebox(&"normal", &"TextEdit", _caja("InputField02a", [2, 2, 2, 2], [8, 6, 8, 6]))
	tema.set_stylebox(&"focus", &"TextEdit", StyleBoxEmpty.new())
	tema.set_color(&"font_color", &"TextEdit", TINTA)


static func _pestanas(tema : Theme) -> void:
	# Las pestanas son las mismas teclas, pero la elegida es la levantada: se lee
	# como "esta es la que esta arriba".
	var elegida := _caja("Button01a_4", [3, 3, 3, 8], [12, -1, 12, -1])
	var otra := _caja("Button01a_2", [3, 6, 3, 5], [12, -1, 12, -1])
	otra.modulate_color = Color(0.88, 0.88, 0.88)
	var encima := _caja("Button01a_3", [3, 4, 3, 7], [12, -1, 12, -1])

	for tipo in [&"TabContainer", &"TabBar"]:
		tema.set_stylebox(&"tab_selected", tipo, elegida)
		tema.set_stylebox(&"tab_unselected", tipo, otra)
		tema.set_stylebox(&"tab_hovered", tipo, encima)
		tema.set_stylebox(&"tab_disabled", tipo, otra)
		tema.set_stylebox(&"tab_focus", tipo, StyleBoxEmpty.new())
		tema.set_color(&"font_selected_color", tipo, TINTA)
		tema.set_color(&"font_unselected_color", tipo, TINTA_SUAVE)
		tema.set_color(&"font_hovered_color", tipo, TINTA)
		tema.set_constant(&"h_separation", tipo, 2)

	tema.set_stylebox(&"panel", &"TabContainer", _caja("FrameSlot01a", [3, 3, 3, 3], [8, 8, 8, 8]))


static func _listas(tema : Theme) -> void:
	tema.set_stylebox(&"panel", &"ItemList", _caja("FrameSlot01a", [3, 3, 3, 3], [4, 4, 4, 4]))
	tema.set_stylebox(&"focus", &"ItemList", StyleBoxEmpty.new())
	var elegido := _caja("FrameSlot03a", [3, 3, 3, 3], [2, 2, 2, 2])
	tema.set_stylebox(&"selected", &"ItemList", elegido)
	tema.set_stylebox(&"selected_focus", &"ItemList", elegido)
	tema.set_stylebox(&"cursor", &"ItemList", StyleBoxEmpty.new())
	tema.set_stylebox(&"cursor_unfocused", &"ItemList", StyleBoxEmpty.new())
	tema.set_stylebox(&"hovered", &"ItemList", _caja("FrameSlot02a", [3, 3, 3, 3], [2, 2, 2, 2]))
	tema.set_color(&"font_color", &"ItemList", TINTA)
	tema.set_color(&"font_selected_color", &"ItemList", TINTA)
	tema.set_color(&"font_hovered_color", &"ItemList", CREMA)

	tema.set_stylebox(&"panel", &"Tree", _caja("FrameSlot01a", [3, 3, 3, 3], [4, 4, 4, 4]))
	tema.set_color(&"font_color", &"Tree", TINTA)


static func _barras(tema : Theme) -> void:
	tema.set_stylebox(&"background", &"ProgressBar", _caja("Bar01a", [2, 2, 2, 2], [2, 2, 2, 2]))
	tema.set_stylebox(&"fill", &"ProgressBar", _caja("Bar10a", [2, 3, 2, 3], [2, 2, 2, 2]))
	tema.set_color(&"font_color", &"ProgressBar", TINTA)

	# Los sprites de barra son horizontales; para la vertical alcanza con el
	# hueco gris de fondo y un tirador cremita, que no tienen direccion.
	var fondo := _caja("FrameSlot01b", [3, 3, 3, 3], [4, 4, 4, 4])
	var tirador := _caja("Handle03a", [2, 2, 2, 2], [4, 6, 4, 6])
	var tirador_encima := tirador.duplicate()
	tirador_encima.modulate_color = Color(1.0, 0.92, 0.8)
	for tipo in [&"VScrollBar", &"HScrollBar"]:
		tema.set_stylebox(&"scroll", tipo, fondo)
		tema.set_stylebox(&"scroll_focus", tipo, fondo)
		tema.set_stylebox(&"grabber", tipo, tirador)
		tema.set_stylebox(&"grabber_highlight", tipo, tirador_encima)
		tema.set_stylebox(&"grabber_pressed", tipo, tirador_encima)

	var riel := _caja("Bar06a", [3, 3, 3, 3], [0, 4, 0, 4])
	tema.set_stylebox(&"slider", &"HSlider", riel)
	tema.set_icon(&"grabber", &"HSlider", _textura("Handle02a"))
	tema.set_icon(&"grabber_highlight", &"HSlider", _textura("Handle02a"))


static func _menus(tema : Theme) -> void:
	tema.set_stylebox(&"panel", &"PopupMenu", _caja("Frame01a", [4, 4, 4, 4], [6, 6, 6, 6]))
	tema.set_stylebox(&"hover", &"PopupMenu", _caja("FrameSlot03a", [3, 3, 3, 3], [6, 2, 6, 2]))
	tema.set_color(&"font_color", &"PopupMenu", TINTA)
	tema.set_color(&"font_hover_color", &"PopupMenu", TINTA)
	tema.set_color(&"font_disabled_color", &"PopupMenu", TINTA_SUAVE)
	tema.set_color(&"font_separator_color", &"PopupMenu", TINTA_SUAVE)
	tema.set_constant(&"v_separation", &"PopupMenu", 8)

	tema.set_stylebox(&"panel", &"TooltipPanel", _caja("InputField01a", [2, 2, 2, 4], [8, 6, 8, 8]))
	tema.set_color(&"font_color", &"TooltipLabel", TINTA)


static func _casillas(tema : Theme) -> void:
	var si := _textura("ToggleOn01a")
	var no := _textura("ToggleOff01a")
	for tipo in [&"CheckBox", &"CheckButton"]:
		tema.set_icon(&"checked", tipo, si)
		tema.set_icon(&"unchecked", tipo, no)
		tema.set_icon(&"radio_checked", tipo, si)
		tema.set_icon(&"radio_unchecked", tipo, no)
		tema.set_icon(&"checked_disabled", tipo, si)
		tema.set_icon(&"unchecked_disabled", tipo, no)
		tema.set_color(&"font_color", tipo, TINTA)
		tema.set_color(&"font_hover_color", tipo, TINTA)
		tema.set_color(&"font_pressed_color", tipo, TINTA)
		tema.set_color(&"font_hover_pressed_color", tipo, TINTA)
		tema.set_constant(&"h_separation", tipo, 8)
		var vacia := StyleBoxEmpty.new()
		vacia.content_margin_left = 2
		for estado in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
			tema.set_stylebox(estado, tipo, vacia)
	tema.set_icon(&"checked", &"CheckButton", _textura("ToggleOn03a"))
	tema.set_icon(&"unchecked", &"CheckButton", _textura("ToggleOff03a"))


## Las piezas de Ventana (escenas/ui/componentes/Ventana.gd), que las pide por
## variacion de tipo y no por ruta de sprite.
static func _ventana(tema : Theme) -> void:
	_variacion(tema, &"BarraTitulo", &"PanelContainer")
	tema.set_stylebox(&"panel", &"BarraTitulo", _caja("Banner03a", [5, 2, 2, 4], [14, 2, 6, 6]))

	_variacion(tema, &"TituloVentana", &"Label")
	tema.set_font_size(&"font_size", &"TituloVentana", 18)
	tema.set_color(&"font_color", &"TituloVentana", TINTA)

	tema.set_icon(&"cerrar", &"Ventana", _textura("ButtonCross01a"))
	tema.set_icon(&"aceptar", &"Ventana", _textura("ButtonCheck01a"))


## La consola de chat va sobre el mundo: fondo translucido y letra de terminal.
static func _consola(tema : Theme) -> void:
	var consola : FontFile = load(FUENTE_CONSOLA)

	_variacion(tema, &"PanelConsola", &"PanelContainer")
	var fondo := _caja("FrameSlot01c", [3, 3, 3, 3], [8, 6, 8, 6])
	fondo.modulate_color = Color(0.25, 0.25, 0.3, 1.0)
	tema.set_stylebox(&"panel", &"PanelConsola", fondo)

	_variacion(tema, &"TextoConsola", &"RichTextLabel")
	for fuente in [&"normal_font", &"bold_font", &"italics_font", &"mono_font"]:
		tema.set_font(fuente, &"TextoConsola", consola)
	for tamano in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"mono_font_size"]:
		tema.set_font_size(tamano, &"TextoConsola", TAMANO_FUENTE_CONSOLA)
	tema.set_color(&"default_color", &"TextoConsola", CREMA)
	tema.set_color(&"font_outline_color", &"TextoConsola", Color(0, 0, 0, 0.8))
	tema.set_constant(&"outline_size", &"TextoConsola", 3)
	tema.set_stylebox(&"normal", &"TextoConsola", StyleBoxEmpty.new())
	tema.set_stylebox(&"focus", &"TextoConsola", StyleBoxEmpty.new())

	_variacion(tema, &"CampoConsola", &"LineEdit")
	tema.set_font(&"font", &"CampoConsola", consola)
	tema.set_font_size(&"font_size", &"CampoConsola", TAMANO_FUENTE_CONSOLA)
	var campo := _caja("InputField01a", [2, 2, 2, 4], [8, 2, 8, 6])
	tema.set_stylebox(&"normal", &"CampoConsola", campo)
	var campo_apagado := campo.duplicate()
	campo_apagado.modulate_color = Color(1, 1, 1, 0.45)
	tema.set_stylebox(&"read_only", &"CampoConsola", campo_apagado)

	# Las pestanas de filtro de la consola: chicas, para no tapar el mundo.
	_variacion(tema, &"FiltroConsola", &"Button")
	tema.set_font(&"font", &"FiltroConsola", consola)
	tema.set_font_size(&"font_size", &"FiltroConsola", 18)
	var filtros := {
		&"normal": _caja("Button01a_2", [3, 6, 3, 5], [8, 0, 8, 2]),
		&"hover": _caja("Button01a_3", [3, 4, 3, 7], [8, 0, 8, 2]),
		&"pressed": _caja("Button01a_4", [3, 3, 3, 8], [8, 0, 8, 2]),
		&"hover_pressed": _caja("Button01a_4", [3, 3, 3, 8], [8, 0, 8, 2]),
	}
	(filtros[&"normal"] as StyleBoxTexture).modulate_color = Color(0.92, 0.92, 0.92, 0.9)
	for estado in filtros:
		tema.set_stylebox(estado, &"FiltroConsola", filtros[estado])


# --- Utilidades ------------------------------------------------------------------


## Registra una variacion de tipo: el nombre que se escribe en theme_type_variation.
static func _variacion(tema : Theme, nombre : StringName, base : StringName) -> void:
	tema.set_type_variation(nombre, base)


## Carga un sprite del pack por su nombre corto ("Button01a_3").
static func _textura(nombre : String) -> Texture2D:
	var ruta := DIR_SPRITES + nombre + ".png"
	var textura : Texture2D = load(ruta)
	if textura == null:
		push_error("ConstructorTema: falta el sprite %s. Correr herramientas/escalar_sprites_ui.py." % ruta)
	return textura


## Arma una caja de nueve partes desde un sprite.
##
## Los dos juegos de margenes van en orden izquierda, arriba, derecha, abajo, y
## en unidades distintas a proposito. Los de textura —cuanto borde no se estira—
## van en pixeles del sprite original, porque se leen mirando el PNG del pack.
## Los de contenido —cuanto aire queda alrededor de lo de adentro— van en
## pixeles de pantalla, porque se deciden mirando el juego. Un -1 en el de
## contenido deja que Godot use el de textura, que es lo que hacen los botones
## para que el texto quede centrado en la cara de la tecla.
static func _caja(sprite : String, textura_margenes : Array, contenido : Array) -> StyleBoxTexture:
	var caja := StyleBoxTexture.new()
	caja.texture = _textura(sprite)
	caja.texture_margin_left = textura_margenes[0] * ESCALA
	caja.texture_margin_top = textura_margenes[1] * ESCALA
	caja.texture_margin_right = textura_margenes[2] * ESCALA
	caja.texture_margin_bottom = textura_margenes[3] * ESCALA
	caja.content_margin_left = contenido[0]
	caja.content_margin_top = contenido[1]
	caja.content_margin_right = contenido[2]
	caja.content_margin_bottom = contenido[3]
	return caja
