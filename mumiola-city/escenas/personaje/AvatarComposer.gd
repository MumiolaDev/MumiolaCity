class_name AvatarComposer
extends Node3D

## Slots del avatar por partes, en orden de dibujo.
##
## El maniquin de KayKit trae seis mallas separadas pesadas al mismo esqueleto
## (ArmLeft, ArmRight, Body, Head, LegLeft, LegRight), asi que la estructura
## para intercambiar partes ya existe. Lo que falta es contenido: el pack no
## trae prendas alternativas que ponerle. El esqueleto ademas tiene huesos de
## enganche tipo handslot.l, que son donde van a colgar las herramientas.
const SLOTS := [&"cuerpo", &"piernas", &"torso", &"cabeza", &"tocado"]

## Se emite cuando una animacion de transicion termino y arranca la que encadena.
##
## Existe para que quien pidio la transicion pueda esperarla. Levantarse de una
## cama, por ejemplo, tiene que mover al personaje recien cuando la animacion
## termino; moverlo antes lo hace aparecer de pie al costado del mueble mientras
## todavia se esta incorporando.
signal transicion_terminada(destino : StringName)

## Traduce los nombres logicos del juego a los del pack de animaciones.
##
## Es lo que evita que el resto del codigo conozca a KayKit: el juego pide
## &"caminar" y aqui se decide que eso es "MovementBasic/Walking_A". Cambiar de
## pack de animaciones es reescribir este diccionario y nada mas.
@export var animaciones : Dictionary = {
	&"idle": "Rig_Medium_General/Idle_A",
	&"caminar": "Rig_Medium_MovementBasic/Walking_A",
	# Las tres poses vienen completas del pack: entrar, mantenerse y salir. Es
	# lo que permite que PoseBehavior sea un solo script con tres .tres.
	&"sentarse": "Rig_Medium_Simulation/Sit_Chair_Down",
	&"sentado": "Rig_Medium_Simulation/Sit_Chair_Idle",
	&"levantarse": "Rig_Medium_Simulation/Sit_Chair_StandUp",

	&"sentarse_piso": "Rig_Medium_Simulation/Sit_Floor_Down",
	&"sentado_piso": "Rig_Medium_Simulation/Sit_Floor_Idle",
	&"levantarse_piso": "Rig_Medium_Simulation/Sit_Floor_StandUp",

	&"acostarse": "Rig_Medium_Simulation/Lie_Down",
	&"acostado": "Rig_Medium_Simulation/Lie_Idle",
	&"levantarse_cama": "Rig_Medium_Simulation/Lie_StandUp",
}

## El AnimationPlayer que trae el modelo importado, con las bibliotecas cargadas.
@export var animador : AnimationPlayer
## El esqueleto del modelo. Todavia no se usa: es donde van a colgar los
## BoneAttachment3D de cada slot cuando haya un personaje modular.
@export var esqueleto : Skeleton3D

## Animaciones que tienen que repetirse mientras dure el estado, por su nombre
## logico.
##
## Las animaciones importadas desde glTF llegan con loop_mode en NONE porque el
## formato no distingue las ciclicas de las que se reproducen una vez, asi que
## hay que marcarlas a mano. Sin esto, caminar un trayecto largo deja al avatar
## congelado en el ultimo cuadro cuando la animacion termina.
@export var en_bucle : Array[StringName] = [&"idle", &"caminar",
	&"sentado", &"sentado_piso", &"acostado"]

var _actual : StringName = &""

## Que animacion arrancar cuando termine la que esta sonando. Vacio si ninguna.
var _encadenada : StringName = &""


func _ready() -> void:
	if animador == null:
		push_error("AvatarComposer en %s: falta asignar 'animador' en el inspector." % name)
		return
	_aplicar_bucles()
	animador.animation_finished.connect(_al_terminar_animacion)


## Marca como ciclicas las animaciones listadas en en_bucle. Modifica el recurso
## en memoria, no el archivo importado.
func _aplicar_bucles() -> void:
	for logica in en_bucle:
		if not animaciones.has(logica):
			continue
		var anim : Animation = animador.get_animation(animaciones[logica])
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR


## Reproduce una animacion por su nombre logico.
##
## Ignora el pedido si ya es la que esta sonando, porque quien llama lo hace
## desde _physics_process y reiniciarla en cada fotograma la dejaria congelada
## en el primer cuadro.
func reproducir(animacion : StringName) -> void:
	if animador == null:
		return
	if animacion == _actual:
		return
	if not animaciones.has(animacion):
		push_warning("AvatarComposer: no hay animacion mapeada para " + animacion)
		return
	_actual = animacion
	animador.play(animaciones[animacion])


## Reproduce una animacion de transicion y, al terminar, pasa a otra.
##
## Es lo que separa sentarse de estar sentado: Sit_Chair_Down se reproduce una
## vez y deja al avatar en la pose que Sit_Chair_Idle continua en bucle. Sin el
## encadenado habria que elegir entre no tener transicion o quedarse congelado en
## el ultimo cuadro de ella.
##
## Solo funciona con animaciones que no esten en en_bucle: una animacion ciclica
## no termina nunca, asi que animation_finished no se emite jamas.
## Devuelve si de verdad va a encadenar. Con false, quien llamo sabe que no hay
## ninguna transicion que esperar y que el estado final ya esta puesto.
func reproducir_encadenado(transicion : StringName, destino : StringName) -> bool:
	if animador == null:
		return false
	if not animaciones.has(transicion):
		# Sin la transicion, al menos que el estado final se vea.
		reproducir(destino)
		return false

	_encadenada = destino
	_actual = &""      # forzar el play aunque la transicion ya estuviera sonando
	reproducir(transicion)
	return true


## Encadena la animacion pendiente, si la hay.
func _al_terminar_animacion(_nombre : StringName) -> void:
	if _encadenada == &"":
		return
	var siguiente := _encadenada
	_encadenada = &""
	reproducir(siguiente)
	transicion_terminada.emit(siguiente)


## Devuelve el nombre logico de la animacion que se esta reproduciendo.
func animacion_actual() -> StringName:
	return _actual


## Cambia la malla de un slot del avatar.
##
## Pendiente de contenido, no de estructura: cada slot corresponde a una de las
## mallas del maniquin (torso -> Body, piernas -> las dos Leg, cabeza -> Head) y
## reemplazarla es asignar otro Mesh al MeshInstance3D. Queda sin implementar
## hasta que haya prendas que intercambiar, porque no habria con que probarlo.
func actualizar_parte(_slot : StringName, _malla : Mesh) -> void:
	pass


## Pone o quita la malla correspondiente a un item equipado.
func aplicar_equipo(_item : ItemDefinition) -> void:
	pass
