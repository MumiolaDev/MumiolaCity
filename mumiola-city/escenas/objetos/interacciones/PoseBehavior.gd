class_name PoseBehavior
extends InteractionBehavior

## Adoptar una pose sobre un mueble: sentarse, sentarse en el piso, acostarse.
##
## Generaliza el viejo SentarseBehavior. Las tres son el mismo gesto —entrar en
## una pose, mantenerla, salir— con animaciones y numeros distintos, asi que son
## tres .tres del mismo script y no tres scripts. El pack trae las tres
## secuencias completas, que es lo que lo hace posible.
##
## Como todo InteractionBehavior es sin estado y compartido: las cincuenta sillas
## de una sala apuntan al mismo .tres, asi que quien esta sentado no puede vivir
## aca. Vive en objeto.estado_runtime, que ademas es el lugar correcto por otro
## motivo: quien esta sentado no tiene sentido que siga siendo cierto manana, asi
## que no va en la instancia persistente (D3).
##
## Los ocupantes se guardan por **id de actor y no por nodo**, y esa es la quinta
## costura del multijugador. Un nodo del cliente A no existe en el B; lo que se
## replica es el hecho —"el actor 7 esta en pose sobre el mueble de la celda
## 3,4"— y cada cliente resuelve su propio nodo con GameManager.actor_por_id().
## Hacerlo ahora es gratis porque este script se reescribia igual; hacerlo
## despues, con quince comportamientos encima, es tocarlos todos.

## Bajo que clave se guardan los ocupantes dentro de estado_runtime.
##
## Una sola para todas las poses y no una por verbo: lo que esta ocupado es el
## mueble, no el verbo. Nadie puede estar sentado y acostado en la misma cama al
## mismo tiempo, y con una clave por verbo eso seria posible.
const CLAVE_OCUPANTES := &"pose_ocupantes"

## Cuantos caben a la vez: 1 una silla, 3 un banco.
@export var capacidad : int = 1
## Corrimiento en metros sobre el plano del piso, para modelos cuyo asiento no
## queda en el centro de su celda.
@export var offset_visual : Vector2 = Vector2.ZERO
## Cuanto girar al que entra en la pose respecto del mueble, en grados.
##
## No es un ajuste fino sino un desfase de modelado: el frente de una silla y el
## frente de un avatar no tienen por que ser el mismo eje. Con 180 el avatar
## queda mirando hacia afuera del respaldo. Ademas decide por donde se sale, que
## es siempre la celda que tiene enfrente.
@export_range(-180.0, 180.0, 90.0) var giro_salida : float = 180.0

@export_group("Animacion")
## La que entra en la pose. Se reproduce una vez.
@export var animacion_entrada : StringName = &"sentarse"
## La que se mantiene mientras dura. Tiene que estar en AvatarComposer.en_bucle.
@export var animacion_bucle : StringName = &"sentado"
## La que sale de la pose. Se reproduce una vez.
@export var animacion_salida : StringName = &"levantarse"

@export_group("Texto")
## Como se llama el verbo cuando quien pregunta ya esta en la pose.
@export var etiqueta_salir : String = "Levantarse"


## Devuelve los ids de quienes estan en pose sobre el objeto.
##
## Descarta los ids que ya no resuelven a nadie vivo en vez de confiar en la
## lista: un NPC liberado —o una sala descargada— deja una entrada que no apunta
## a nada, y sin esta limpieza la silla quedaria ocupada para siempre por un
## fantasma. Con nodos habia que preguntar is_instance_valid(); con ids, si
## nadie responde a ese id, es lo mismo.
func ocupantes(objeto : WorldObject) -> Array:
	if objeto == null:
		return []

	var guardados : Array = objeto.estado_runtime.get(CLAVE_OCUPANTES, [])
	var vivos : Array = []
	for id in guardados:
		if GameManager.actor_por_id(id) != null:
			vivos.append(id)

	if vivos.size() != guardados.size():
		objeto.estado_runtime[CLAVE_OCUPANTES] = vivos
	return vivos


## Devuelve si un actor concreto esta en pose sobre el objeto.
func tiene_a(actor : Node, objeto : WorldObject) -> bool:
	var id := GameManager.id_de_actor(actor)
	return id != &"" and id in ocupantes(objeto)


## Devuelve como se llama el verbo para este actor: entrar, o salir si ya esta.
func etiqueta_para(actor : Node, objeto : WorldObject) -> String:
	return etiqueta_salir if tiene_a(actor, objeto) else etiqueta


## Los datos que necesita el actor para adoptar la pose.
##
## Un diccionario y no seis parametros: asi agregar un dato a la pose no cambia
## la firma de adoptar_pose() ni obliga al personaje a conocer esta clase.
func datos_de_pose() -> Dictionary:
	return {
		"offset": offset_visual,
		"giro": giro_salida,
		"entrada": animacion_entrada,
		"bucle": animacion_bucle,
		"salida": animacion_salida,
	}


## Devuelve si el actor puede usar la pose ahora mismo.
##
## Estar en ella tambien cuenta: es la unica forma de que el menu contextual
## ofrezca salir. Es el mismo gesto que en Habbo, donde volver a hacer clic sobre
## la silla te para.
func puede_interactuar(actor : Node, objeto : WorldObject) -> bool:
	if actor == null or objeto == null:
		return false
	# El actor se comprueba por metodo y no por tipo a proposito: el parametro es
	# Node para que un NPC pueda sentarse sin heredar de PersonajeControlador.
	if not actor.has_method(&"adoptar_pose"):
		return false
	# Sin id no hay forma de anotarlo, y anotar un nodo seria justo lo que esta
	# clase dejo de hacer.
	if GameManager.id_de_actor(actor) == &"":
		return false

	if tiene_a(actor, objeto):
		return true
	return ocupantes(objeto).size() < capacidad


## Pone al actor en la pose, o lo saca si ya estaba. Devuelve si ocurrio.
##
## Un solo verbo que alterna, y no dos comportamientos: entrar y salir son el
## mismo gesto sobre el mismo mueble, y separarlos obligaria a que el menu
## mostrara siempre uno de los dos en gris.
##
## Anota al ocupante solo despues de que el actor confirmo que adopto la pose:
## si se anotara antes y fallara, el mueble quedaria ocupado por alguien que
## sigue parado al lado.
func interactuar(actor : Node, objeto : WorldObject) -> bool:
	if not puede_interactuar(actor, objeto):
		return false

	if tiene_a(actor, objeto):
		return salir(actor, objeto)

	if not actor.adoptar_pose(objeto, datos_de_pose()):
		return false

	var dentro := ocupantes(objeto)
	dentro.append(GameManager.id_de_actor(actor))
	objeto.estado_runtime[CLAVE_OCUPANTES] = dentro
	return true


## Saca al actor de la pose. Devuelve si efectivamente ocurrio.
##
## Lo desanota aunque el actor ya no este en pose: si se quedara anotado, el
## mueble seguiria ocupado por nadie.
func salir(actor : Node, objeto : WorldObject) -> bool:
	if actor == null or objeto == null:
		return false

	var id := GameManager.id_de_actor(actor)
	var dentro := ocupantes(objeto)
	if not (id in dentro):
		return false

	dentro.erase(id)
	objeto.estado_runtime[CLAVE_OCUPANTES] = dentro

	# Solo se le pide al actor que salga si todavia estaba en pose. Cuando el
	# camino es el inverso —el actor salio y avisa al mueble— ya no lo esta, y
	# volver a pedirselo seria recursion.
	if actor.has_method(&"esta_en_pose") and actor.esta_en_pose() \
			and actor.has_method(&"dejar_pose"):
		actor.dejar_pose()

	# Devuelve true porque lo que esta funcion promete es desanotarlo, y eso ya
	# ocurrio, sin importar por cual de los dos caminos se llego.
	return true
