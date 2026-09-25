extends Node

## Sabe que sala se esta jugando y quien es el jugador. Es el punto al que el
## resto del juego le pregunta "donde estamos" sin tener que conocer el arbol.
##
## Hay una sola sala cargada a la vez, como en Habbo. Una sala es la escena
## generica Sala.tscn mas su documento, que se le pide a Servidor por id; al irse,
## se guarda si cambio y se libera. Con muchas salas de jugadores no tiene
## sentido tenerlas todas vivas, y es ademas lo que va a pasar con red: el
## cliente tiene la sala donde esta y nada mas.
##
## No usa change_scene_to_packed() para cambiar de sala: eso reemplaza el arbol
## entero, jugador incluido. Cambiar de sala cambia un hijo del contenedor, y el
## resto del mundo —jugador, interfaz— sigue donde estaba.
##
## Un autoload sobrevive a los cambios de escena, asi que todo lo que guarda son
## referencias que pueden quedar colgando. Por eso registrar_contenedor() limpia
## el estado y todo acceso comprueba is_instance_valid(): una referencia muerta
## aca no da error, devuelve basura.

## La escena de la que nace toda sala.
const ESCENA_SALA := preload("res://escenas/mundo/salas/Sala.tscn")
## Donde se entra si no hay otro lugar al que ir.
const SALA_INICIAL := &"pub_plaza"

## Se emite al terminar de cambiar de sala, con la sala ya encendida y el
## jugador ya adentro.
signal sala_cambiada(sala : RoomController)
## Cambio algo de lo que se muestra de la sala actual —su nombre— sin cambiar
## de sala.
signal sala_actualizada(sala : RoomController)
## Se emite al empezar a irse de una sala, antes del fundido.
signal saliendo_de_sala(sala : RoomController)
## Se emite cuando un jugador se registra, para lo que necesite engancharse a el.
signal jugador_registrado(jugador : PersonajeControlador)

## Se paso de recorrer la sala a editarla, o al reves.
signal modo_cambiado(modo : Modo)


## En que esta el jugador: recorriendo la sala o construyendola.
##
## Vive aca y no en el editor porque varias cosas que no se conocen entre si
## necesitan leerlo: el personaje deja de caminar al clic, el menu contextual
## deja de abrirse, la vista previa aparece. Con el modo colgando del editor,
## todas ellas tendrian que conocer al editor.
enum Modo { JUGANDO, EDITANDO }

## Cuantos menus hay abiertos ahora mismo. Un contador y no un bool porque nada
## impide que algun dia haya dos.
var _menus_abiertos : int = 0

## Quien es quien: id de actor -> nodo vivo.
##
## Existe para que el estado de sesion se pueda guardar por identidad y no por
## nodo. Es la quinta costura del multijugador: un nodo del cliente A no existe
## en el B, asi que lo que se replica es el hecho —"el actor 7 esta sentado en el
## mueble de la celda 3,4"— y cada cliente resuelve su propio nodo.
var _actores : Dictionary = {}

var _jugador : PersonajeControlador = null
var _contenedor : Node = null
var _sala_actual : RoomController = null
## Quien esta jugando: el id y el nombre del perfil. Hasta que haya perfiles es
## uno de desarrollo; el id es tambien el id de actor del jugador y el duenio de
## sus salas, asi que es el mismo que usa el servidor para darle permisos.
var _perfil_id : StringName = &"dev"
var _nombre_jugador : String = "Jugador"
## Si hay un cambio de sala en curso. Un segundo pedido mientras tanto se
## rechaza: dos cargas cruzadas dejarian al jugador en la que termine ultima.
var _cambiando : bool = false
var _modo : Modo = Modo.JUGANDO


func _ready() -> void:
	Servidor.chat_recibido.connect(_al_recibir_chat)


## El jugador se anota solo desde su _ready().
##
## Al reves —que el manager lo busque con get_node("/root/...")— ata el manager a
## la forma del arbol, que cambia cada vez que se reorganiza una escena.
func registrar_jugador(jugador : PersonajeControlador) -> void:
	_jugador = jugador
	registrar_actor(jugador, _perfil_id)
	jugador_registrado.emit(jugador)


## Anota un actor bajo un id, para poder resolverlo despues sin guardar el nodo.
##
## Devuelve el id con el que quedo. El jugador se anota con el id de su perfil y
## los NPCs se anotarian con el suyo; el dia del servidor, el id es el de la
## cuenta y no cambia nada de lo que lo usa.
func registrar_actor(actor : Node, id : StringName) -> StringName:
	if actor == null or id == &"":
		return &""
	_actores[id] = actor
	return id


## Devuelve el actor de un id, o null si no hay ninguno vivo con ese id.
func actor_por_id(id : StringName) -> Node:
	var actor = _actores.get(id)
	if actor == null or not is_instance_valid(actor):
		_actores.erase(id)
		return null
	return actor


## Devuelve el id de un actor, o vacio si no esta anotado.
##
## Recorre en vez de guardar el id en el nodo para no obligar a que todo actor
## tenga un campo: lo que define la identidad es estar en este registro. Con un
## punado de actores por sala, recorrerlo no es un costo.
func id_de_actor(actor : Node) -> StringName:
	if actor == null:
		return &""
	for id in _actores:
		if _actores[id] == actor:
			return id
	return &""


## Declara de que nodo cuelga la sala. Lo llama el mundo al arrancar.
##
## Limpia la sala actual porque un mundo nuevo trae salas nuevas: la anterior ya
## no existe aunque la referencia siga pareciendo valida.
func registrar_contenedor(nodo : Node) -> void:
	_contenedor = nodo
	_sala_actual = null
	_cambiando = false


## Devuelve el jugador actual, o null si todavia no se registro ninguno.
func jugador_actual() -> PersonajeControlador:
	return _jugador if is_instance_valid(_jugador) else null


## Devuelve la sala que se esta jugando, o null.
func sala_actual() -> RoomController:
	return _sala_actual if is_instance_valid(_sala_actual) else null


## Devuelve si hay un cambio de sala en curso.
func cambiando_de_sala() -> bool:
	return _cambiando


## Va a una sala por su id. Devuelve OK, o por que no se pudo.
##
## Es una corrutina: se llama con await si importa saber cuando termino. Con el
## servidor local y la pantalla ya cubierta no espera nada y la sala queda
## puesta en el mismo cuadro —asi arranca el mundo—; lo que si espera es el
## fundido de salida, que es solo visual.
##
## El orden es el que evita mostrar una sala a medio armar y el que no pierde
## nada si algo falla:
##
##  1. Cubrir. Pedir el documento. Si no llega, descubrir y quedarse donde se
##     estaba: la sala vieja sigue ahi.
##  2. Armar la nueva entera —estructura y objetos— antes de encenderla.
##  3. Mudar al jugador, que se levanta de donde estuviera sentado.
##  4. Recien ahi guardar y liberar la vieja.
##  5. Descubrir.
func ir_a(id : StringName) -> Errores.Codigo:
	if _cambiando:
		return Errores.Codigo.CAMBIO_EN_CURSO
	var anterior := sala_actual()
	if anterior != null and anterior.id_sala == id:
		return Errores.Codigo.ES_LA_SALA_ACTUAL
	if not is_instance_valid(_contenedor):
		push_error("GameManager: no hay contenedor de salas. ¿Falta registrar_contenedor()?")
		return Errores.Codigo.SALA_NO_EXISTE

	_cambiando = true
	if anterior != null:
		saliendo_de_sala.emit(anterior)
	await Transicion.cubrir()

	var respuesta : Dictionary = await Servidor.obtener_sala(id)
	if not Errores.ok(respuesta.codigo):
		_cambiando = false
		await Transicion.descubrir()
		return respuesta.codigo

	var sala : RoomController = ESCENA_SALA.instantiate()
	sala.name = "Sala_%s" % id
	_contenedor.add_child(sala)
	var codigo := sala.from_dict(respuesta.doc)
	if not Errores.ok(codigo):
		sala.queue_free()
		_cambiando = false
		await Transicion.descubrir()
		return codigo
	sala.encuadrar_entrada()

	# Se entra jugando: el historial de deshacer y el modo editor son de la sala
	# que se esta dejando.
	cambiar_modo(Modo.JUGANDO)
	if anterior != null:
		anterior.desactivar()
	sala.activar()
	_sala_actual = sala

	var jugador := jugador_actual()
	if jugador != null:
		jugador.entrar_en(sala)

	if anterior != null:
		await _guardar_si_cambio(anterior)
		anterior.queue_free()

	_cambiando = false
	sala_cambiada.emit(sala)
	Consola.sistema("Entraste a %s." % sala.nombre_sala)
	await Transicion.descubrir()
	return Errores.Codigo.OK


## Guarda la sala actual. Devuelve OK, o por que no se pudo.
func guardar_sala_actual() -> Errores.Codigo:
	var sala := sala_actual()
	if sala == null:
		return Errores.Codigo.SALA_NO_EXISTE
	var codigo : Errores.Codigo = await Servidor.guardar_sala(sala.to_dict(), _perfil_id)
	if Errores.ok(codigo):
		sala.marcar_guardada()
	return codigo


## Vuelve a cargar la sala actual desde lo guardado, descartando lo que cambio.
func recargar_sala_actual() -> Errores.Codigo:
	var sala := sala_actual()
	if sala == null:
		return Errores.Codigo.SALA_NO_EXISTE
	var respuesta : Dictionary = await Servidor.obtener_sala(sala.id_sala)
	if not Errores.ok(respuesta.codigo):
		return respuesta.codigo
	var codigo := sala.from_dict(respuesta.doc)
	var jugador := jugador_actual()
	if jugador != null:
		jugador.entrar_en(sala)
	return codigo


## Guarda una sala si cambio desde la ultima vez. Un rechazo se avisa y no
## frena nada: irse de una sala ajena que no se puede guardar es normal.
func _guardar_si_cambio(sala : RoomController) -> void:
	if not sala.esta_sucia():
		return
	var codigo : Errores.Codigo = await Servidor.guardar_sala(sala.to_dict(), _perfil_id)
	if Errores.ok(codigo):
		sala.marcar_guardada()
	else:
		Consola.error("No se guardaron los cambios de %s: %s" % [sala.nombre_sala, Errores.mensaje(codigo)])


## Guarda la sala actual si cambio. Lo usan quien cierra el juego y quien sale
## del editor.
func guardar_si_cambio() -> void:
	var sala := sala_actual()
	if sala != null:
		await _guardar_si_cambio(sala)


## Devuelve el id del perfil que esta jugando.
func perfil_id() -> StringName:
	return _perfil_id


## Cerrar la ventana guarda lo que haya cambiado en la sala. Lo demas del
## perfil lo guarda SaveManager, que escucha lo mismo.
func _notification(que : int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar_si_cambio()


## Avisa algo al jugador.
##
## Es un canal y no una llamada a la UI: quien avisa no tiene que saber si hay
## una caja de chat mostrandolo. Desde que existe la consola, es un atajo a
## Consola.sistema(), y se conserva porque todo el juego ya avisa por aca.
func avisar(texto : String) -> void:
	Consola.sistema(texto)


## Avisa el mensaje que le corresponde a un codigo de rechazo. Un OK no avisa
## nada, porque no hay nada que explicar.
func avisar_error(codigo : Errores.Codigo) -> void:
	Consola.error_codigo(codigo)


## El jugador dice algo en voz alta, en la sala donde esta.
##
## Pasa por aca y no directo a la consola porque decir es un acto del jugador
## en una sala: con red, esto es lo que se manda al servidor para que lo
## reparta entre los que estan ahi.
func decir(texto : String) -> Errores.Codigo:
	var sala := sala_actual()
	var sala_id := sala.id_sala if sala != null else &""
	return await Servidor.enviar_chat(sala_id, _perfil_id, _nombre_jugador, texto)


## Muestra lo que se dijo en la sala donde esta el jugador. Lo de otras salas
## no llega: con red, el servidor ni lo manda.
func _al_recibir_chat(sala_id : StringName, autor_id : StringName, autor_nombre : String,
		texto : String) -> void:
	var sala := sala_actual()
	if sala == null or sala.id_sala == sala_id:
		Consola.chat(autor_id, autor_nombre, texto)


## Devuelve el nombre con el que se muestra el jugador.
func nombre_jugador() -> String:
	return _nombre_jugador


## Avisa que un menu se abrio o se cerro.
##
## Pasa por aca y no del menu al personaje directamente por la regla de
## direccion: la UI conoce a los managers, el mundo lee un dato, y ninguno de
## los dos sabe que existe el otro.
func avisar_menu(abierto : bool) -> void:
	_menus_abiertos = maxi(0, _menus_abiertos + (1 if abierto else -1))


## Devuelve si hay algun menu abierto ahora mismo.
##
## Sirve para que el clic que cancela un menu no cuente ademas como una orden al
## mundo: cerrar un menu y mandar al personaje a caminar son dos intenciones
## distintas, y el mismo clic no puede ser las dos.
##
## Se pregunta por el estado y no por un aviso al cerrarse, que fue el primer
## intento y estaba tarde: el orden real es que _unhandled_input ve el clic
## **antes** de que el popup emita popup_hide. Cuando el mundo mira, el menu
## todavia esta abierto — y eso es justamente lo que hay que mirar.
func hay_menu_abierto() -> bool:
	return _menus_abiertos > 0


## Devuelve en que modo esta el juego.
func modo() -> Modo:
	return _modo


## Devuelve si se esta editando la sala.
##
## Existe ademas de modo() porque "if GameManager.editando():" se lee mucho mejor
## que comparar contra el enum en los quince lugares que van a preguntarlo.
func editando() -> bool:
	return _modo == Modo.EDITANDO


## Cambia de modo y avisa. Devuelve si hubo cambio.
##
## No deja editar una sala que no es tuya: es la misma regla que el servidor
## aplica al guardarla, y dejar entrar al editor para rechazar despues cada
## cambio seria mentirle al jugador.
##
## Al salir del modo editor se olvida el historial de la sala: deshacer despues
## de haberse ido a recorrerla desharia cosas que el jugador ya dio por hechas.
## Y se guarda lo que haya cambiado: salir del editor es dar la obra por hecha.
func cambiar_modo(nuevo : Modo) -> bool:
	if nuevo == _modo:
		return false
	var sala := sala_actual()
	if nuevo == Modo.EDITANDO and sala != null and not sala.puede_editar(jugador_actual()):
		return false

	_modo = nuevo
	if _modo == Modo.JUGANDO and sala != null:
		sala.olvidar_historial()
		guardar_si_cambio()

	modo_cambiado.emit(_modo)
	return true


## Alterna entre recorrer y editar. Devuelve OK, o por que no se pudo.
func alternar_modo() -> Errores.Codigo:
	if cambiar_modo(Modo.JUGANDO if editando() else Modo.EDITANDO):
		return Errores.Codigo.OK
	return Errores.Codigo.NO_ES_TUYO
