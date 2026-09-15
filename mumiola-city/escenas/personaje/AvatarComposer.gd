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

## Traduce los nombres logicos del juego a los del pack de animaciones.
##
## Es lo que evita que el resto del codigo conozca a KayKit: el juego pide
## &"caminar" y aqui se decide que eso es "MovementBasic/Walking_A". Cambiar de
## pack de animaciones es reescribir este diccionario y nada mas.
@export var animaciones : Dictionary = {
	&"idle": "Rig_Medium_General/Idle_A",
	&"caminar": "Rig_Medium_MovementBasic/Walking_A",
	&"sentado": "Rig_Medium_Simulation/Sit_Chair_Idle",
}

## El AnimationPlayer que trae el modelo importado, con las bibliotecas cargadas.
@export var animador : AnimationPlayer
## El esqueleto del modelo. Todavia no se usa: es donde van a colgar los
## BoneAttachment3D de cada slot cuando haya un personaje modular.
@export var esqueleto : Skeleton3D

var _actual : StringName = &""


## Reproduce una animacion por su nombre logico.
##
## Ignora el pedido si ya es la que esta sonando, porque quien llama lo hace
## desde _physics_process y reiniciarla en cada fotograma la dejaria congelada
## en el primer cuadro.
func reproducir(animacion : StringName) -> void:
	if animacion == _actual:
		return
	if not animaciones.has(animacion):
		push_warning("AvatarComposer: no hay animacion mapeada para " + animacion)
		return
	_actual = animacion
	animador.play(animaciones[animacion])


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
