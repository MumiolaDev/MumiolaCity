extends RefCounted
class_name Comandos

## El registro de los comandos de la consola: "/ayuda", "/ir plaza", "/dar silla 2".
##
## Agregar un comando es una linea, desde donde tenga sentido:
##
##     Comandos.registrar(&"inv", _cmd_inventario, "Lista lo que llevas.")
##
## Quien registra es quien sabe hacer la cosa: la consola registra /ayuda y
## /limpiar, el mundo registra /ir y /editar. Por eso el registro es estatico y
## no vive dentro de nadie: si viviera en el mundo, la consola tendria que
## conocerlo, y al reves.
##
## La funcion recibe los argumentos ya separados y devuelve un Errores.Codigo,
## como cualquier operacion que puede fallar. Lo que tenga para contar lo cuenta
## ella por Consola; el registro solo se ocupa del rechazo.
##
## Los comandos marcados como debug son andamio de desarrollo —darse objetos,
## saltar a cualquier sala—. Con red, un cliente no puede ejecutarlos: el dia
## del servidor se filtran por esa marca, sin buscarlos uno por uno.

## nombre -> {nombre, funcion, ayuda, uso, debug}
static var _registro : Dictionary = {}


## Registra un comando. Volver a registrar un nombre reemplaza el anterior, que es
## lo que pasa cuando el mundo se recarga y vuelve a anotar los suyos.
static func registrar(nombre : StringName, funcion : Callable, ayuda : String,
		uso : String = "", debug : bool = false) -> void:
	_registro[nombre] = {
		"nombre": nombre,
		"funcion": funcion,
		"ayuda": ayuda,
		"uso": uso,
		"debug": debug,
	}


## Borra un comando del registro.
static func quitar(nombre : StringName) -> void:
	_registro.erase(nombre)


## Ejecuta una linea sin la barra: "dar silla 2".
##
## Un comando cuyo dueno ya no existe —registrado por un mundo que se descargo—
## cuenta como desconocido en vez de reventar al llamarlo.
static func ejecutar(linea : String) -> Errores.Codigo:
	var partes := linea.strip_edges().split(" ", false)
	if partes.is_empty():
		return Errores.Codigo.COMANDO_DESCONOCIDO

	var nombre := StringName(partes[0].to_lower())
	var comando : Dictionary = _registro.get(nombre, {})
	if comando.is_empty() or not (comando.funcion as Callable).is_valid():
		return Errores.Codigo.COMANDO_DESCONOCIDO

	var argumentos := partes.slice(1)
	var resultado = (comando.funcion as Callable).call(argumentos)
	# Un comando que no tiene como fallar puede no devolver nada.
	return resultado if resultado is int else Errores.Codigo.OK


## Devuelve si existe un comando con ese nombre.
static func existe(nombre : StringName) -> bool:
	return _registro.has(nombre)


## Devuelve los comandos registrados, ordenados por nombre, para la ayuda.
static func lista(incluir_debug : bool = true) -> Array[Dictionary]:
	var salida : Array[Dictionary] = []
	for nombre in _registro:
		var c : Dictionary = _registro[nombre]
		if c.debug and not incluir_debug:
			continue
		if not (c.funcion as Callable).is_valid():
			continue
		salida.append(c)
	salida.sort_custom(func(a : Dictionary, b : Dictionary) -> bool:
		return String(a.nombre) < String(b.nombre))
	return salida


## Devuelve la forma de uso de un comando, lista para mostrar: "/dar <item> [cantidad]".
static func uso_de(nombre : StringName) -> String:
	var c : Dictionary = _registro.get(nombre, {})
	if c.is_empty():
		return ""
	return ("/%s %s" % [nombre, c.uso]).strip_edges()
