extends Node

## El unico lugar por donde pasa lo que manana vive en un servidor: las salas,
## los perfiles y el chat.
##
## Es la costura de la red, en el mismo sentido que las cinco de la fase 3: nada
## de red ahora, pero el lugar por donde entra ya esta hecho. La interfaz y
## GameManager le piden cosas a Servidor y nunca tocan un archivo; hoy atiende
## ServidorLocal, que escribe en user://, y el dia del servidor atiende otra
## clase con los mismos metodos. Nadie de afuera se entera.
##
## Todo lo que manana es una consulta remota se llama con await:
##
##     var r := await Servidor.obtener_sala(id)
##
## Hoy la respuesta llega en el acto —el await no espera nada—, pero escrito asi
## desde el principio, el dia que la respuesta tarde no hay que cambiar ninguna
## llamada. Lo que es un evento que llega solo (un mensaje de chat de otro) no
## se pide: se escucha por senal.
##
## Las respuestas que traen datos son diccionarios con "codigo" y el dato, porque
## un await devuelve un solo valor y el motivo del rechazo no se puede perder.

## Alguien dijo algo en una sala. Llega tambien lo que dijo el propio jugador:
## asi el chat se muestra por un solo camino, y con red el eco es el del
## servidor, que es la prueba de que el mensaje salio.
signal chat_recibido(sala_id : StringName, autor_id : StringName, autor_nombre : String, texto : String)

## Sin tipo a proposito: es lo que se reemplaza por la implementacion en red, y
## tiparlo con ServidorLocal ataria todo a esa clase.
var _backend = ServidorLocal.new()


## Resumenes de las salas publicas: {id, nombre, descripcion, tipo, propietario, objetos}.
func listar_salas_publicas() -> Array[Dictionary]:
	return await _backend.listar_salas_publicas()


## Resumenes de las salas de un jugador.
func listar_salas_de(propietario : StringName) -> Array[Dictionary]:
	return await _backend.listar_salas_de(propietario)


## El documento completo de una sala: {"codigo", "doc"}.
func obtener_sala(id : StringName) -> Dictionary:
	return await _backend.obtener_sala(id)


## Las formas para crear salas, con su estructura para dibujar la miniatura.
func plantillas() -> Array[Dictionary]:
	return await _backend.plantillas()


## Crea una sala desde una plantilla: {"codigo", "id"}.
func crear_sala(nombre : String, plantilla_id : StringName, propietario : StringName) -> Dictionary:
	return await _backend.crear_sala(nombre, plantilla_id, propietario)


## Guarda el documento de una sala en nombre de un actor.
func guardar_sala(doc : Dictionary, actor_id : StringName) -> Errores.Codigo:
	return await _backend.guardar_sala(doc, actor_id)


## Cambia el nombre de una sala.
func renombrar_sala(id : StringName, nombre : String, actor_id : StringName) -> Errores.Codigo:
	return await _backend.renombrar_sala(id, nombre, actor_id)


## Borra una sala.
func borrar_sala(id : StringName, actor_id : StringName) -> Errores.Codigo:
	return await _backend.borrar_sala(id, actor_id)


## Dice algo en una sala. La respuesta llega por chat_recibido, a todos los que
## esten ahi —hoy, solo al que lo dijo—.
func enviar_chat(sala_id : StringName, autor_id : StringName, autor_nombre : String,
		texto : String) -> Errores.Codigo:
	texto = texto.strip_edges().substr(0, 200)
	if texto.is_empty():
		return Errores.Codigo.OK
	chat_recibido.emit(sala_id, autor_id, autor_nombre, texto)
	return Errores.Codigo.OK
