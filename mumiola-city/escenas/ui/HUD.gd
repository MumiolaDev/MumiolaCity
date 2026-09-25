class_name HUD
extends CanvasLayer

## La capa fija de interfaz: donde estas.
##
## Se suscribe y nunca la consultan. Se puede borrar del arbol y el juego sigue
## funcionando, que es el test de que la capa de UI esta bien puesta.
##
## Los avisos pasajeros y el texto de ayuda que vivian aca se fueron: los avisos
## a la consola de abajo a la izquierda, que los guarda y deja releerlos, y la
## ayuda a su propia ventana. La barra de energia y los Ducados se fueron con la
## economia.

@onready var _sala : Label = $Sala


func _ready() -> void:
	GameManager.sala_cambiada.connect(mostrar_sala)
	# Ponerse al dia con lo que ya paso: un HUD que entra tarde al arbol tiene
	# que mostrar la sala vigente, no esperar al proximo cambio.
	mostrar_sala(GameManager.sala_actual())


## Escribe en que sala esta el jugador.
func mostrar_sala(sala : RoomController) -> void:
	if sala == null:
		_sala.text = ""
		return
	_sala.text = sala.nombre_sala if sala.nombre_sala != "" else String(sala.name)
