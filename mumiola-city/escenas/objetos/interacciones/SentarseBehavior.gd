class_name SentarseBehavior
extends InteractionBehavior

## El verbo de sentarse. El primer comportamiento concreto del sistema de verbos.
##
## Como todo InteractionBehavior es sin estado y compartido: las cincuenta sillas
## de una sala apuntan al mismo .tres, asi que quien esta sentado no puede vivir
## aca. Vive en objeto.estado_runtime, que ademas es el lugar correcto por otro
## motivo: quien esta sentado no tiene sentido que siga siendo cierto manana, asi
## que no va en la instancia persistente (D3).

## Bajo que clave se guardan los ocupantes dentro de estado_runtime.
const CLAVE_OCUPANTES := &"sentarse_ocupantes"

## Cuantos caben a la vez: 1 una silla, 3 un banco.
@export var capacidad : int = 1
## Corrimiento en metros sobre el plano del piso, para modelos cuyo asiento no
## queda en el centro de su celda.
@export var offset_visual : Vector2 = Vector2.ZERO
## Nombre logico de la animacion, tal como lo entiende AvatarComposer.
@export var animacion : StringName = &"sentado"
## Cuanto girar al que se sienta respecto del mueble, en grados.
##
## No es un ajuste fino sino un desfase de modelado: el frente de una silla y el
## frente de un avatar no tienen por que ser el mismo eje. Con 180 el avatar
## queda mirando hacia afuera del respaldo. Ademas decide por donde se baja, que
## es siempre la celda que tiene enfrente.
@export_range(-180.0, 180.0, 90.0) var giro_asiento : float = 180.0


## Devuelve quienes estan sentados ahora mismo en el objeto.
##
## Filtra las referencias muertas en vez de confiar en la lista. estado_runtime
## es el unico lugar del juego que guarda referencias a nodos vivos, y un NPC
## liberado —o una sala descargada— deja una entrada que apunta a nada. Sin este
## filtro, una silla se quedaria ocupada para siempre por un fantasma.
func ocupantes(objeto : WorldObject) -> Array:
	if objeto == null:
		return []

	var guardados : Array = objeto.estado_runtime.get(CLAVE_OCUPANTES, [])
	var vivos : Array = []
	for quien in guardados:
		if is_instance_valid(quien):
			vivos.append(quien)

	if vivos.size() != guardados.size():
		objeto.estado_runtime[CLAVE_OCUPANTES] = vivos
	return vivos


## Devuelve si el actor puede sentarse en el objeto ahora mismo.
func puede_interactuar(actor : Node, objeto : WorldObject) -> bool:
	if actor == null or objeto == null:
		return false
	# El actor se comprueba por metodo y no por tipo a proposito: el parametro es
	# Node para que un NPC pueda sentarse sin heredar de PersonajeControlador.
	if not actor.has_method(&"sentarse_en"):
		return false

	var sentados := ocupantes(objeto)
	if actor in sentados:
		return false
	return sentados.size() < capacidad


## Sienta al actor. Devuelve si efectivamente ocurrio.
##
## Vuelve a comprobar puede_interactuar() aunque WorldObject.ejecutar() ya lo
## haya hecho, y registra al ocupante solo despues de que el actor confirmo que
## se sento: si se anotara antes y sentarse fallara, la silla quedaria ocupada
## por alguien que sigue parado al lado.
func interactuar(actor : Node, objeto : WorldObject) -> bool:
	if not puede_interactuar(actor, objeto):
		return false
	if not actor.sentarse_en(objeto, offset_visual, animacion, giro_asiento):
		return false

	var sentados := ocupantes(objeto)
	sentados.append(actor)
	objeto.estado_runtime[CLAVE_OCUPANTES] = sentados
	return true


## Levanta al actor del objeto. Devuelve si efectivamente ocurrio.
##
## Lo saca de la lista aunque levantarse() devuelva false: si el actor ya no esta
## sentado, dejarlo anotado mantendria la silla ocupada por nadie.
func levantarse(actor : Node, objeto : WorldObject) -> bool:
	if actor == null or objeto == null:
		return false

	var sentados := ocupantes(objeto)
	if not (actor in sentados):
		return false

	sentados.erase(actor)
	objeto.estado_runtime[CLAVE_OCUPANTES] = sentados

	if actor.has_method(&"levantarse"):
		return actor.levantarse()
	return true
