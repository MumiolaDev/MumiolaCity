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

var _activa : bool = false


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
	pos.y = grid.altura_piso
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


# colocar_objeto() y retirar_objeto() son el paso 4b y llegan junto con el paso
# 5. Su firma ya esta decidida —colocar_objeto() devuelve Errores.Codigo y el
# objeto creado se recupera con grid.objeto_en(celda), ver D16— pero no se
# pueden escribir todavia: reciben y devuelven ItemInstance, y tanto ese recurso
# como WorldObject son stubs vacios. Escribirlos ahora seria adivinar su forma.
