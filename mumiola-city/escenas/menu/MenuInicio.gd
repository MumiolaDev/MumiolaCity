extends Control
class_name MenuInicio

## La primera pantalla: elegir con que perfil jugar, crear uno o salir.
##
## Un perfil es el equivalente local de una cuenta. Entrar es iniciar sesion
## con el —Servidor.iniciar_sesion(), que con red es donde va la autenticacion—
## y recien despues cargar el mundo, porque el jugador toma su identidad del
## perfil al nacer.
##
## Crear un perfil entra directo con el: nadie crea un personaje para quedarse
## mirando la lista.

const ESCENA_MUNDO := "res://escenas/mundo/Mundo.tscn"

@onready var _perfiles : ItemList = %Perfiles
@onready var _entrar : Button = %Entrar
@onready var _borrar : Button = %Borrar
@onready var _nombre : LineEdit = %Nombre
@onready var _crear : Button = %Crear
@onready var _aviso : Label = %Aviso
@onready var _opciones_boton : Button = %OpcionesBoton
@onready var _salir : Button = %Salir
@onready var _opciones : OpcionesUI = %OpcionesUI
@onready var _version : Label = %Version


func _ready() -> void:
	OpcionesUI.aplicar_guardadas()
	_version.text = "v%s · catalogo %s" % [
		ProjectSettings.get_setting("application/config/version", "0.1"), ItemDatabase.version()]
	_aviso.text = ""

	_perfiles.item_selected.connect(func(_i : int) -> void: _actualizar_botones())
	_perfiles.item_activated.connect(func(_i : int) -> void: entrar())
	_entrar.pressed.connect(entrar)
	_borrar.pressed.connect(_borrar_elegido)
	_nombre.text_changed.connect(func(_t : String) -> void: _actualizar_botones())
	_nombre.text_submitted.connect(func(_t : String) -> void: crear())
	_crear.pressed.connect(crear)
	_opciones_boton.pressed.connect(_opciones.abrir)
	_salir.pressed.connect(func() -> void: get_tree().quit())

	await refrescar()
	if _perfiles.item_count == 0 or _perfiles.is_item_disabled(0):
		_nombre.grab_focus()
	else:
		_entrar.grab_focus()
	# Si se llega desde el juego, el telon viene cerrado.
	Transicion.descubrir()


## Vuelve a pedir la lista de perfiles y elige el mas reciente.
func refrescar() -> void:
	_perfiles.clear()
	for p in await Servidor.listar_perfiles():
		var i := _perfiles.add_item(p.nombre)
		_perfiles.set_item_metadata(i, StringName(p.id))
		_perfiles.set_item_tooltip(i, "Jugado por ultima vez %s" % _hace(p.ultima_vez))
	if _perfiles.item_count == 0:
		var i := _perfiles.add_item("Todavia no hay perfiles. Crea uno abajo.")
		_perfiles.set_item_disabled(i, true)
		_perfiles.set_item_selectable(i, false)
	else:
		_perfiles.select(0)
	_actualizar_botones()


## Entra al mundo con el perfil elegido.
func entrar() -> void:
	var elegidos := _perfiles.get_selected_items()
	if elegidos.is_empty():
		return
	var id = _perfiles.get_item_metadata(elegidos[0])
	if id is StringName:
		await _entrar_con(id)


## Crea un perfil con el nombre escrito y entra con el.
func crear() -> void:
	if _crear.disabled:
		return
	_mostrar_aviso("")
	var r : Dictionary = await Servidor.crear_perfil(_nombre.text)
	if not Errores.ok(r.codigo):
		_mostrar_aviso(Errores.mensaje(r.codigo))
		return
	await _entrar_con(r.id)


func _entrar_con(id : StringName) -> void:
	_bloquear(true)
	var r : Dictionary = await Servidor.iniciar_sesion(id)
	if not Errores.ok(r.codigo):
		_mostrar_aviso(Errores.mensaje(r.codigo))
		_bloquear(false)
		refrescar()
		return
	GameManager.iniciar_sesion(r.doc)
	await Transicion.cubrir("Entrando...")
	get_tree().change_scene_to_file(ESCENA_MUNDO)


func _borrar_elegido() -> void:
	var elegidos := _perfiles.get_selected_items()
	if elegidos.is_empty():
		return
	var id : StringName = _perfiles.get_item_metadata(elegidos[0])
	var nombre := _perfiles.get_item_text(elegidos[0])
	var r : Dictionary = await Dialogo.confirmar(self, "Borrar perfil",
		"¿Borrar a %s, con sus salas y todo lo que lleva? No se puede deshacer." % nombre,
		"Borrar").respondido
	if not r.aceptado:
		return
	var codigo : Errores.Codigo = await Servidor.borrar_perfil(id)
	_mostrar_aviso("" if Errores.ok(codigo) else Errores.mensaje(codigo))
	refrescar()


func _actualizar_botones() -> void:
	var hay := not _perfiles.get_selected_items().is_empty()
	_entrar.disabled = not hay
	_borrar.disabled = not hay
	_crear.disabled = _nombre.text.strip_edges().length() < ServidorLocal.LARGO_MINIMO_JUGADOR


func _bloquear(si : bool) -> void:
	for b in [_entrar, _borrar, _crear, _opciones_boton, _salir]:
		b.disabled = si
	if not si:
		_actualizar_botones()


func _mostrar_aviso(texto : String) -> void:
	_aviso.text = texto


## "hace 3 dias", para la ayuda de cada perfil.
func _hace(segundos_unix : int) -> String:
	if segundos_unix <= 0:
		return "nunca"
	var pasaron := int(Time.get_unix_time_from_system()) - segundos_unix
	if pasaron < 120:
		return "recien"
	if pasaron < 7200:
		return "hace %d minutos" % (pasaron / 60)
	if pasaron < 172800:
		return "hace %d horas" % (pasaron / 3600)
	return "hace %d dias" % (pasaron / 86400)
