extends Node

## El canal de todo lo que se le dice al jugador: chat, avisos del juego,
## errores y lineas de depuracion. La caja de abajo a la izquierda es solo una
## forma de mostrarlo.
##
## Reemplaza al viejo GameManager.aviso, que era un String suelto. Un mensaje
## ahora es un dato con canal, autor y hora, porque el chat va a viajar por la
## red y lo que viaja tiene que decir quien lo dijo. Es un Dictionary plano y no
## una clase para que se serialice a JSON sin traduccion.
##
## Se suscribe quien quiera mostrarlo y nadie lo consulta, igual que el HUD
## viejo: borrar la caja de chat del arbol quita la funcion, no rompe nada.
##
## Guarda un historial acotado, asi una interfaz que aparece tarde —la del mundo,
## al entrar desde el menu— se pone al dia con lo que ya se dijo.
##
## Va primero entre los autoloads (D9): no depende de nadie y todos le avisan.

## Se publico un mensaje. Ver _nuevo() para los campos.
signal mensaje_publicado(mensaje : Dictionary)
## Se borro el historial.
signal limpiada()
## Se prendio o apago el canal de depuracion.
signal debug_cambiado(visible : bool)

enum Canal { CHAT, SISTEMA, ERROR, DEBUG }

## Cuantos mensajes se recuerdan. Mas que eso es scroll que nadie lee, y crece
## sin techo en una sesion larga.
const MAXIMO := 200

## Si las lineas de depuracion se muestran. Arranca prendido en las builds de
## desarrollo y apagado en las de release.
var mostrar_debug : bool = OS.is_debug_build()

var _historial : Array[Dictionary] = []


func _ready() -> void:
	Comandos.registrar(&"ayuda", _cmd_ayuda, "Lista los comandos.")
	Comandos.registrar(&"limpiar", _cmd_limpiar, "Borra la consola.")
	Comandos.registrar(&"debug", _cmd_debug, "Muestra u oculta las lineas de depuracion.", "[on|off]")


## Publica una linea de chat de alguien.
func chat(autor_id : StringName, autor_nombre : String, texto : String) -> void:
	_publicar(_nuevo(Canal.CHAT, texto, autor_id, autor_nombre))


## Publica un aviso del juego: "Entraste a Plaza", "Sala guardada".
func sistema(texto : String) -> void:
	_publicar(_nuevo(Canal.SISTEMA, texto))


## Publica un rechazo o un problema que el jugador tiene que ver.
func error(texto : String) -> void:
	_publicar(_nuevo(Canal.ERROR, texto))


## Publica el mensaje de un codigo de rechazo. Un OK no dice nada.
func error_codigo(codigo : Errores.Codigo) -> void:
	if not Errores.ok(codigo):
		error(Errores.mensaje(codigo))


## Publica una linea de depuracion. Se guarda aunque no se muestre, para que
## prender /debug deje ver lo que ya paso.
func debug(texto : String) -> void:
	_publicar(_nuevo(Canal.DEBUG, texto))


## Procesa lo que el jugador escribio en la caja.
##
## Con barra es un comando y se resuelve aca. Sin barra es chat, y se lo entrega
## a GameManager, que sabe quien es el jugador y —con red— a quien mandarselo.
func enviar(texto : String) -> Errores.Codigo:
	texto = texto.strip_edges()
	if texto.is_empty():
		return Errores.Codigo.OK

	if not texto.begins_with("/"):
		return GameManager.decir(texto)

	var linea := texto.substr(1)
	var codigo := Comandos.ejecutar(linea)
	if codigo == Errores.Codigo.USO_INCORRECTO:
		var nombre := StringName(linea.split(" ", false)[0].to_lower()) if linea.strip_edges() != "" else &""
		error("%s  Uso: %s" % [Errores.mensaje(codigo), Comandos.uso_de(nombre)])
	else:
		error_codigo(codigo)
	return codigo


## Devuelve los mensajes recordados, del mas viejo al mas nuevo.
func historial() -> Array[Dictionary]:
	return _historial


## Borra el historial.
func limpiar() -> void:
	_historial.clear()
	limpiada.emit()


## Prende o apaga el canal de depuracion.
func set_mostrar_debug(valor : bool) -> void:
	if valor == mostrar_debug:
		return
	mostrar_debug = valor
	debug_cambiado.emit(valor)


func _nuevo(canal : Canal, texto : String, autor_id : StringName = &"",
		autor_nombre : String = "") -> Dictionary:
	return {
		"canal": canal,
		"texto": texto,
		"autor_id": autor_id,
		"autor_nombre": autor_nombre,
		"tiempo": int(Time.get_unix_time_from_system()),
	}


func _publicar(mensaje : Dictionary) -> void:
	_historial.append(mensaje)
	if _historial.size() > MAXIMO:
		_historial = _historial.slice(_historial.size() - MAXIMO)
	# Tambien a la salida estandar: los tests y las corridas headless no tienen
	# caja de chat, y ahi es donde mas hace falta leer que paso.
	if mensaje.canal != Canal.CHAT:
		print("[%s] %s" % [Canal.keys()[mensaje.canal].to_lower(), mensaje.texto])
	mensaje_publicado.emit(mensaje)


# --- Comandos propios ------------------------------------------------------------


func _cmd_ayuda(_args : PackedStringArray) -> Errores.Codigo:
	var lineas : Array[String] = ["Comandos:"]
	for c in Comandos.lista(mostrar_debug):
		lineas.append("  %s — %s" % [Comandos.uso_de(c.nombre), c.ayuda])
	sistema("\n".join(lineas))
	return Errores.Codigo.OK


func _cmd_limpiar(_args : PackedStringArray) -> Errores.Codigo:
	limpiar()
	return Errores.Codigo.OK


func _cmd_debug(args : PackedStringArray) -> Errores.Codigo:
	if args.is_empty():
		set_mostrar_debug(not mostrar_debug)
	elif args[0] in ["on", "si", "1"]:
		set_mostrar_debug(true)
	elif args[0] in ["off", "no", "0"]:
		set_mostrar_debug(false)
	else:
		return Errores.Codigo.USO_INCORRECTO
	sistema("Depuracion %s." % ("visible" if mostrar_debug else "oculta"))
	return Errores.Codigo.OK
