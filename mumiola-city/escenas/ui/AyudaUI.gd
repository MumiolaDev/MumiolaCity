extends Ventana
class_name AyudaUI

## La ventana de ayuda: como se juega y que comandos hay.
##
## Reemplaza al texto crudo que el mundo escribia en una esquina. Los controles
## son una tabla de datos aca abajo; los comandos no se escriben en ningun lado,
## se leen del registro de Comandos cada vez que se abre la ventana. Asi la
## pestana de comandos no se puede desactualizar: un comando nuevo aparece solo.

## Seccion -> lista de [tecla, que hace].
const CONTROLES := [
	["Moverse", [
		["Clic izquierdo", "caminar hasta ahi"],
		["Clic derecho sobre algo", "ver que se puede hacer con eso"],
	]],
	["Camara", [
		["Rueda", "acercar y alejar"],
		["Boton del medio", "arrastrar la vista"],
		["Q / E", "girar la sala"],
		["Inicio", "volver a encuadrar la sala"],
	]],
	["Editar la sala", [
		["B", "pasar de jugar a editar y volver"],
		["Clic", "colocar lo elegido en la paleta"],
		["Clic derecho", "quitar"],
		["R", "girar lo que vas a colocar"],
		["Ctrl+Z / Ctrl+Y", "deshacer y rehacer"],
		["Ctrl+S", "guardar la sala"],
	]],
	["Interfaz", [
		["Enter", "hablar"],
		["/", "escribir un comando"],
		["F1", "esta ayuda"],
	]],
]

var _comandos : RichTextLabel = null


func _ready() -> void:
	titulo = "Ayuda"
	custom_minimum_size = Vector2(520, 440)

	var pestanas := TabContainer.new()
	pestanas.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var controles := _hoja("Controles")
	controles.text = _texto_controles()
	pestanas.add_child(controles)

	_comandos = _hoja("Comandos")
	pestanas.add_child(_comandos)

	add_child(pestanas)
	super._ready()


## Abre la ventana con la lista de comandos al dia.
func abrir() -> void:
	_comandos.text = _texto_comandos()
	super.abrir()


func _unhandled_key_input(evento : InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_F1:
		alternar()
		get_viewport().set_input_as_handled()


func _hoja(nombre : String) -> RichTextLabel:
	var hoja := RichTextLabel.new()
	hoja.name = nombre
	hoja.bbcode_enabled = true
	hoja.fit_content = false
	hoja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return hoja


func _texto_controles() -> String:
	var lineas : Array[String] = []
	for seccion in CONTROLES:
		lineas.append("[b]%s[/b]" % seccion[0])
		for fila in seccion[1]:
			lineas.append("   [color=#a0521a]%s[/color] — %s" % [fila[0], fila[1]])
		lineas.append("")
	return "\n".join(lineas)


func _texto_comandos() -> String:
	var lineas : Array[String] = ["Se escriben en la caja de chat, empezando con /.", ""]
	for c in Comandos.lista(Consola.mostrar_debug):
		var marca := "  [color=#808ba1](debug)[/color]" if c.debug else ""
		lineas.append("[color=#a0521a]%s[/color]%s" % [Comandos.uso_de(c.nombre).replace("[", "[lb]"), marca])
		lineas.append("   %s" % c.ayuda)
	return "\n".join(lineas)
