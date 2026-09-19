class_name InteractionBehavior
extends Resource

## La clase base del sistema de verbos (GDD 6.1).
##
## Sin estado y compartida: cincuenta sillas apuntan al mismo .tres. De ahi la
## regla que no se puede romper: ni puede_interactuar() ni interactuar() escriben
## en self. Lo que haya que recordar va en objeto.estado_runtime si es de la
## sesion, o en objeto.instancia si tiene que sobrevivir a cerrar el juego (D3).
##
## Solo la base. Los comportamientos concretos —SentarseBehavior el primero— son
## el paso 6; esto existe ahora porque ItemDefinition.interacciones y
## WorldObject.ejecutar() necesitan el tipo.

## Identificador interno del verbo: &"sentarse". Sin tildes ni mayusculas (D4).
@export var verbo : StringName = &""
## Texto que ve el jugador en el menu contextual: "Sentarse".
@export var etiqueta : String = ""
@export var icono : Texture2D
## Si el actor tiene que estar en una celda vecina para poder hacerlo.
@export var requiere_adyacencia : bool = true


## Devuelve como se llama este verbo para un actor concreto.
##
## Por defecto es la etiqueta fija, pero un comportamiento puede cambiarla segun
## el estado: la misma silla dice "Sentarse" o "Levantarse" segun quien pregunte.
## El recurso es compartido por cincuenta muebles, asi que la etiqueta no se puede
## guardar en self: se calcula cada vez que alguien la pide.
func etiqueta_para(_actor : Node, _objeto : WorldObject) -> String:
	return etiqueta


## Devuelve si el actor puede ejecutar este verbo sobre el objeto, ahora mismo.
##
## Se llama para armar el menu contextual y otra vez dentro de ejecutar(): entre
## que el menu se abre y el jugador elige, alguien mas pudo sentarse en la silla.
func puede_interactuar(_actor : Node, _objeto : WorldObject) -> bool:
	return true


## Ejecuta el verbo. Devuelve si efectivamente ocurrio.
##
## Devuelve bool y no void a proposito (D8): es lo que el dia del servidor
## autoritativo permite rechazar una accion sin haber mutado nada. Cambiar la
## firma con quince comportamientos escritos encima es tocar quince archivos.
func interactuar(_actor : Node, _objeto : WorldObject) -> bool:
	return false
