class_name IndicadorCelda
extends MeshInstance3D

## Resalta la celda que esta bajo el puntero, coloreada segun su estado.
##
## Es una ayuda de desarrollo para ver de un vistazo que celdas estan libres,
## bloqueadas o fuera del suelo, sin tener que deducirlo del comportamiento del
## personaje. Tambien es el germen de la vista previa de colocacion que va a
## necesitar RoomBuilderUI en la fase 4, donde el mismo recuadro va a mostrar en
## rojo si un mueble no cabe.

## La grilla a la que pertenece la celda resaltada.
@export var grid : IsoGrid
## La camara con la que se convierte la posicion del puntero en celda.
@export var camara : Camera3D

@export_group("Colores")
## Hay suelo y no hay nada encima: se puede caminar y se puede construir.
@export var color_libre : Color = Color(0.25, 0.9, 0.45, 0.35)
## Hay suelo pero esta ocupado por una pared o un objeto.
@export var color_bloqueado : Color = Color(0.95, 0.3, 0.25, 0.35)

## Cuanto se levanta el recuadro sobre el piso para que no pelee con el en el
## z-buffer.
@export var alzado : float = 0.02

var _material : StandardMaterial3D


func _ready() -> void:
	if grid == null or camara == null:
		push_error("IndicadorCelda: faltan asignar 'grid' o 'camara' en el inspector.")
		set_process(false)
		return

	var celda := PlaneMesh.new()
	celda.size = Vector2(grid.suelo.cell_size.x, grid.suelo.cell_size.z)
	mesh = celda

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material


func _process(_delta : float) -> void:
	var celda := grid.celda_bajo_puntero(camara, get_viewport().get_mouse_position())

	# Fuera del suelo pintado no se muestra nada: un recuadro flotando sobre el
	# vacio confunde mas de lo que informa.
	if celda == IsoGrid.SIN_CELDA or not grid.celda_valida(celda):
		visible = false
		return

	visible = true
	var pos := grid.celda_a_mundo(celda)
	pos.y = grid.altura_piso + alzado
	global_position = pos
	_material.albedo_color = color_libre if grid.esta_libre(celda) else color_bloqueado
