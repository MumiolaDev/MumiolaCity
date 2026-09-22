class_name RoomController
extends Node3D

## Una sala del mundo: su grilla, sus objetos, su encuadre y quien la posee.
##
## Existe para que "la sala" deje de ser un arreglo implicito de nodos hermanos y
## pase a ser algo que puede existir dos veces. Es lo que habilita la mitad del
## objetivo de la fase 1: ir a tu sala privada y volver.
##
## No conoce al personaje a proposito. activar() enciende la sala y su camara, y
## quien cambia de sala es el que ubica al jugador. Si RoomController importara
## PersonajeControlador, una sala no podria existir sin un jugador adentro, y eso
## romperia los NPCs y la carga de salas para guardarlas o previsualizarlas.

## Se emite al quedar visible y con la camara tomada.
signal activada()
## Se emite al apagarse, antes de que otra sala tome la camara.
signal desactivada()

## Se emite despues de que un objeto quedo colocado y su celda ocupada.
signal objeto_colocado(obj : WorldObject)
## Se emite con el objeto todavia vivo, justo antes de liberarlo, y con su
## instancia ya desprendida: quien escuche puede mirarlo pero ya no es su dueno.
signal objeto_retirado(obj : WorldObject)

## Se emite tras aplicar cualquier operacion, incluidas las de deshacer. Es por
## donde la interfaz de construccion se entera de que la sala cambio.
signal operacion_aplicada(op : OperacionSala)

## Un cuarto de vuelta. Rotar la sala al estilo Habbo es girar el pivote, nunca
## el contenido: los objetos siguen en sus mismas celdas.
const PASO_ROTACION := PI / 2.0

## comun | vivienda | produccion | tienda
@export_enum("comun", "vivienda", "produccion", "tienda") var tipo : String = "comun"
## Nombre visible de la sala.
@export var nombre_sala : String = ""
## Duenio de la sala. Vacio significa publica.
@export var propietario_id : StringName = &""

## Celda en la que aparece quien entra.
##
## No es solo comodidad: D14 define la validacion de que un tabique no parta la
## sala como "todas las celdas con suelo siguen siendo alcanzables desde la
## entrada". Sin una entrada declarada, esa comprobacion no tiene desde donde
## medir.
@export var celda_entrada : Vector2i = Vector2i.ZERO

@onready var grid : IsoGrid = $IsoGrid
@onready var contenedor_objetos : Node3D = $Objetos
@onready var pivote : Node3D = $Pivote
@onready var camara : Camera3D = $Pivote/Camera3D
## La vista previa de colocacion, o null si esta sala no la tiene.
##
## Es opcional por contrato, como la interfaz: sacar el nodo del arbol quita la
## ayuda visual y no rompe nada. El editor de sala la va a pedir por aca.
@onready var indicador : IndicadorCelda = get_node_or_null(^"IndicadorCelda")

var _activa : bool = false

## Lo hecho y lo deshecho, en un solo array con un cursor.
##
## Cada entrada guarda la operacion y su inversa, porque la inversa no se puede
## deducir de la operacion sola: deshacer un pintado necesita saber que habia
## antes, y eso solo se sabe mirando la sala justo antes de aplicarlo.
var _historial : Array = []
var _cursor : int = 0


func _ready() -> void:
	# Toda sala arranca apagada y es el mundo el que enciende una. Asi no hay un
	# orden de nodos en el que dos camaras se peleen por ser la actual.
	desactivar()


## Enciende la sala y le da la camara.
##
## El orden importa: primero se rehabilita el procesamiento, porque una sala
## apagada tiene process_mode en DISABLED y su camara no podria tomar el turno.
func activar() -> void:
	if _activa:
		return
	_activa = true
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	camara.current = true
	activada.emit()


## Apaga la sala: la oculta y detiene el procesamiento de todo lo que cuelga de
## ella, incluido el indicador de celda, que si no seguiria siguiendo al mouse
## desde una sala que nadie esta mirando.
func desactivar() -> void:
	_activa = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	desactivada.emit()


## Devuelve si esta es la sala que se esta jugando.
func esta_activa() -> bool:
	return _activa


## Devuelve la posicion de mundo donde pararse al entrar, ya a la altura del
## piso de esta sala.
func posicion_de_entrada() -> Vector3:
	var pos := grid.celda_a_mundo(celda_entrada)
	return pos


## Gira el encuadre en cuartos de vuelta. Positivo es en sentido horario visto
## desde arriba.
##
## Gira el pivote y no la sala: el contenido conserva sus coordenadas de grilla,
## asi que las celdas, las rutas y la ocupacion no se enteran de nada. El clic
## tampoco, porque celda_bajo_puntero() intersecta contra el plano del piso y no
## depende de por donde mire la camara.
func rotar(pasos : int) -> void:
	pivote.rotation.y += PASO_ROTACION * pasos


## Devuelve los objetos colocados en la sala.
func objetos() -> Array[WorldObject]:
	var lista : Array[WorldObject] = []
	for hijo in contenedor_objetos.get_children():
		if hijo is WorldObject:
			lista.append(hijo)
	return lista


## Coloca un item en la sala. Devuelve OK, o por que no se pudo (D16).
##
## El objeto creado se recupera con grid.objeto_en(celda) despues de un OK, asi
## que no hace falta devolverlo ni usar parametros de salida.
##
## Toma un ItemInstance y no un ItemDefinition (D3): es lo que permite dejar una
## taza servida sobre la mesa y que siga teniendo cafe. La propiedad de esa
## instancia pasa a ser del WorldObject y de nadie mas.
##
## Valida todo antes de crear nada. Si la huella no entra, no queda un nodo
## huerfano dando vueltas ni una celda a medio ocupar.
func colocar_objeto(inst : ItemInstance, celda : Vector2i, rotacion : int = 0) -> Errores.Codigo:
	if inst == null:
		return Errores.Codigo.NO_TIENE_ITEM

	var def := inst.definicion()
	if def == null:
		# No es un rechazo del jugador sino un catalogo incompleto: la instancia
		# apunta a un id que ItemDatabase no tiene.
		push_error("RoomController: no hay definicion para '%s'." % inst.definicion_id)
		return Errores.Codigo.NO_TIENE_ITEM

	if not def.rotable:
		rotacion = 0

	var motivo := grid.motivo_bloqueo(celda, def.tamano_grilla, rotacion)
	if motivo != Errores.Codigo.OK:
		return motivo

	# Aca van, en la fase 4, las dos validaciones que faltan: que la celda este
	# dentro del area editable de la sala (D12, FUERA_DEL_AREA) y que la
	# colocacion no deje una parte de la sala sin salida (D14, PARTIRIA_LA_SALA).
	# El hueco existe desde ahora justamente para que agregarlas no obligue a
	# cambiar esta firma ni a tocar todas las llamadas.

	# Paso 1 de la transaccion, en la fase 2: InventoryManager.quitar_instancia().
	# Tiene que ocurrir aca, antes de que nada mas se escriba, y tiene que poder
	# fallar. Mientras no exista el inventario, quien llama es el dueno de la
	# instancia y se la entrega a la sala.

	var obj := _instanciar(def)
	obj.instancia = inst
	obj.celda_origen = celda
	obj.rotacion_grilla = rotacion

	if not grid.ocupar(celda, def.tamano_grilla, obj, rotacion):
		obj.free()   # nunca entro al arbol, asi que free() y no queue_free()
		return Errores.Codigo.CELDA_OCUPADA

	contenedor_objetos.add_child(obj)
	obj.global_position = grid.centro_de(celda, def.tamano_grilla, rotacion)
	# El signo es el que concuerda con celdas_de(): una rotacion impar cambia
	# ancho por profundidad, y girar -90 grados en Y lleva el eje +X al +Z.
	obj.rotation.y = -PASO_ROTACION * rotacion

	objeto_colocado.emit(obj)
	return Errores.Codigo.OK


## Retira un objeto de la sala y devuelve su instancia, o null si no estaba.
##
## Devuelve *la misma* instancia y no una copia, para que vuelva al inventario
## con su estado intacto: la taza sigue teniendo el cafe.
##
## Le pone null a obj.instancia antes de liberarlo a proposito. La propiedad
## tiene que ser exclusiva (D3): si el inventario conserva la referencia y el
## WorldObject tambien, el mismo objeto existe dos veces. Con Resource, que se
## pasa por referencia, es facilisimo de cometer sin notarlo.
func retirar_objeto(obj : WorldObject) -> ItemInstance:
	if obj == null:
		return null
	if not grid.liberar_objeto(obj):
		# No ocupaba ninguna celda: o no era de esta sala, o ya se retiro.
		return null

	var inst := obj.instancia
	obj.instancia = null

	# Paso 2 de la transaccion, en la fase 2: InventoryManager.agregar_instancia().
	# Puede fallar con el inventario lleno, y ahi hay que devolver el objeto a su
	# celda antes de tocar nada mas.

	objeto_retirado.emit(obj)
	obj.queue_free()
	return inst


## Devuelve si un actor puede modificar esta sala.
##
## Hoy siempre si, porque el sandbox no tiene limites. Existe igual para que el
## dia del servidor autoritativo haya **un** lugar donde poner la comprobacion,
## en vez de tener que buscar todos los sitios que mutan una sala. Los codigos
## NO_ES_TUYO y SIN_PERMISO ya estan en el enum esperandola.
func puede_editar(_actor : Node) -> bool:
	return true


## Aplica una operacion. Es el unico punto que modifica una sala.
##
## Que sea unico es toda la gracia: local se aplica en el acto, online la misma
## operacion se manda, el servidor la valida y la retransmite, y este mismo
## metodo corre en todos los clientes.
##
## registrar en false la aplica sin tocar el historial, que es como se ejecutan
## deshacer y rehacer sin que se registren a si mismos.
func aplicar(op : OperacionSala, registrar : bool = true) -> Errores.Codigo:
	if op == null:
		return Errores.Codigo.NO_TIENE_ITEM
	if not puede_editar(GameManager.jugador_actual()):
		return Errores.Codigo.SIN_PERMISO

	# D25 esta decidida pero no escrita: la superficie es la duena de lo que tiene
	# encima, y eso vive en SuperficieBehavior, que es fase 4. Hasta entonces una
	# operacion con ranura se rechaza en vez de aplicarse al piso, que seria
	# colocar la taza en el lugar equivocado sin decir nada.
	if op.ranura != OperacionSala.SIN_RANURA:
		return Errores.Codigo.NO_ES_SUPERFICIE

	# La inversa se calcula **antes**, mirando la sala como esta ahora: despues de
	# aplicar ya no se puede saber que habia.
	var inversa := _inversa_de(op) if registrar else null

	var codigo := _ejecutar(op)
	if not Errores.ok(codigo):
		return codigo

	if registrar and inversa != null:
		# Una rama nueva descarta lo que se habia deshecho, como en cualquier
		# editor: si deshaces tres pasos y haces algo distinto, los tres viejos
		# dejan de tener sentido.
		_historial.resize(_cursor)
		_historial.append({"op": op, "inversa": inversa})
		_cursor = _historial.size()

	operacion_aplicada.emit(op)
	return codigo


## Deshace la ultima operacion. Devuelve si habia algo que deshacer.
func deshacer() -> bool:
	if _cursor <= 0:
		return false
	_cursor -= 1
	_ejecutar(_historial[_cursor]["inversa"])
	operacion_aplicada.emit(_historial[_cursor]["inversa"])
	return true


## Rehace la ultima operacion deshecha.
func rehacer() -> bool:
	if _cursor >= _historial.size():
		return false
	_ejecutar(_historial[_cursor]["op"])
	operacion_aplicada.emit(_historial[_cursor]["op"])
	_cursor += 1
	return true


func puede_deshacer() -> bool:
	return _cursor > 0


func puede_rehacer() -> bool:
	return _cursor < _historial.size()


## Olvida el historial. Se llama al cargar una sala: deshacer hasta antes de
## abrirla no tendria ningun sentido.
func olvidar_historial() -> void:
	_historial.clear()
	_cursor = 0


## Hace lo que la operacion pide, sin registrar nada.
func _ejecutar(op : OperacionSala) -> Errores.Codigo:
	match op.tipo:
		OperacionSala.Tipo.COLOCAR:
			var inst := ItemInstance.new()
			inst.definicion_id = op.item
			inst.contenido_id = StringName(op.estado.get("contenido", ""))
			inst.contenido_cantidad = int(op.estado.get("contenido_cantidad", 0))
			return colocar_objeto(inst, op.celda, op.rotacion)

		OperacionSala.Tipo.RETIRAR:
			var obj := grid.objeto_en(op.celda)
			if obj == null:
				return Errores.Codigo.NO_TIENE_ITEM
			return Errores.Codigo.OK if retirar_objeto(obj) != null \
				else Errores.Codigo.NO_TIENE_ITEM

		OperacionSala.Tipo.PINTAR:
			return Errores.Codigo.OK if grid.pintar(op.capa, op.celda, op.pieza, op.orientacion) \
				else Errores.Codigo.CELDA_INEXISTENTE

		OperacionSala.Tipo.BORRAR:
			grid.borrar_celda(op.capa, op.celda)
			return Errores.Codigo.OK

	return Errores.Codigo.NO_TIENE_ITEM


## Construye la operacion que devuelve la sala al estado previo.
##
## Devuelve null cuando no hay nada que deshacer —borrar una celda ya vacia— para
## que esas no ensucien el historial.
func _inversa_de(op : OperacionSala) -> OperacionSala:
	match op.tipo:
		OperacionSala.Tipo.COLOCAR:
			return OperacionSala.retirar(op.celda)

		OperacionSala.Tipo.RETIRAR:
			var obj := grid.objeto_en(op.celda)
			if obj == null or obj.instancia == null:
				return null
			return OperacionSala.colocar(obj.instancia.definicion_id, obj.celda_origen,
				obj.rotacion_grilla, {
					"contenido": String(obj.instancia.contenido_id),
					"contenido_cantidad": obj.instancia.contenido_cantidad,
				})

		OperacionSala.Tipo.PINTAR, OperacionSala.Tipo.BORRAR:
			var antes := grid.pieza_en(op.capa, op.celda)
			if antes.is_empty():
				return null if op.tipo == OperacionSala.Tipo.BORRAR \
					else OperacionSala.borrar(op.capa, op.celda)
			return OperacionSala.pintar(op.capa, op.celda, antes["pieza"], antes["orientacion"])

	return null


## Vuelca los objetos colocados a un diccionario serializable.
##
## Guarda el id de la definicion y no una referencia al recurso: la definicion se
## resuelve contra el catalogo del momento de cargar, asi que editar un item no
## invalida las partidas viejas (1.8 de CLASES.md). Es el mismo criterio que D18
## aplica a las piezas de escenario.
##
## Los Vector2i salen como arrays de dos enteros porque JSON no tiene vectores.
func to_dict() -> Dictionary:
	var lista : Array = []
	for obj in objetos():
		if obj.instancia == null:
			continue
		lista.append({
			"item": String(obj.instancia.definicion_id),
			"celda": [obj.celda_origen.x, obj.celda_origen.y],
			"rotacion": obj.rotacion_grilla,
			"contenido": String(obj.instancia.contenido_id),
			"contenido_cantidad": obj.instancia.contenido_cantidad,
		})
	return {"objetos": lista}


## Repuebla la sala desde un diccionario, reemplazando lo que hubiera.
##
## Vacia primero: cargar una partida sobre una sala que ya tiene muebles los
## sumaria a los guardados en vez de reemplazarlos.
##
## Los numeros llegan como float desde JSON, que no distingue enteros, de ahi los
## int(). Sin eso una celda seria Vector2i(3.0, 4.0) y fallaria el tipado.
func from_dict(d : Dictionary) -> void:
	for obj in objetos():
		retirar_objeto(obj)

	for entrada in d.get("objetos", []):
		var inst := ItemInstance.new()
		inst.definicion_id = StringName(entrada.get("item", ""))
		inst.contenido_id = StringName(entrada.get("contenido", ""))
		inst.contenido_cantidad = int(entrada.get("contenido_cantidad", 0))

		var celda : Array = entrada.get("celda", [0, 0])
		if celda.size() != 2:
			continue

		var resultado := colocar_objeto(
			inst, Vector2i(int(celda[0]), int(celda[1])), int(entrada.get("rotacion", 0)))
		if not Errores.ok(resultado):
			push_warning("RoomController '%s': no se pudo restaurar '%s' en %s: %s"
				% [nombre_sala, inst.definicion_id, celda, Errores.mensaje(resultado)])


## Crea el nodo del objeto: su escena propia si la tiene, o un WorldObject pelado.
func _instanciar(def : ItemDefinition) -> WorldObject:
	if def.escena_mundo != null:
		var nodo := def.escena_mundo.instantiate()
		if nodo is WorldObject:
			return nodo
		push_error("RoomController: la escena_mundo de '%s' no es un WorldObject." % def.id)
		nodo.free()
	return WorldObject.new()
