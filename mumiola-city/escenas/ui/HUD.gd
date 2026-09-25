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
	GameManager.sala_actualizada.connect(mostrar_sala)
	# Ponerse al dia con lo que ya paso: un HUD que entra tarde al arbol tiene
	# que mostrar la sala vigente, no esperar al proximo cambio.
	mostrar_sala(GameManager.sala_actual())


## Escribe en que sala esta el jugador, y de quien es.
func mostrar_sala(sala : RoomController) -> void:
	if sala == null:
		_sala.text = ""
		return
	var nombre := sala.nombre_sala if sala.nombre_sala != "" else String(sala.name)
	var de_quien := ""
	if sala.propietario_id == &"":
		de_quien = "sala publica"
	elif sala.propietario_id == GameManager.perfil_id():
		de_quien = "tu sala"
	else:
		de_quien = "de %s" % sala.propietario_id
	_sala.text = "%s\n%s" % [nombre, de_quien]
