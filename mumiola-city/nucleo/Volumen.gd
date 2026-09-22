class_name Volumen
extends RefCounted

## Medir el bulto de un modelo 3D, este o no dentro del arbol.
##
## Existe porque ya son tres los que necesitan lo mismo: el generador de iconos
## para encuadrar, el importador para apoyar cada modelo sobre su base, y
## cualquier cosa que despues quiera saber cuanto ocupa algo. Con tres copias de
## este recorrido, el dia que una escena cambie de forma se arregla una sola.
##
## No usa global_transform a proposito: acumula las transformadas locales hasta
## la raiz que se le pasa. Un nodo que todavia no entro al arbol tiene
## global_transform en identidad y no avisa, asi que medir con el daria resultados
## distintos segun cuando se llame — que es exactamente el bug que hizo salir
## cuarenta y cinco iconos encuadrados desde el origen del mundo.

## Devuelve la caja que envuelve a todas las mallas del subarbol, en el espacio
## de la raiz que se le pasa.
##
## Devuelve una AABB de tamanio cero si no hay ninguna malla, que quien llama
## tiene que distinguir de una malla legitimamente plana mirando tambien la
## posicion.
static func caja_de(raiz : Node3D) -> AABB:
	var mallas : Array[VisualInstance3D] = []
	_juntar_mallas(raiz, mallas)
	if mallas.is_empty():
		return AABB()

	var total := _transformada_hasta(mallas[0], raiz) * mallas[0].get_aabb()
	for i in range(1, mallas.size()):
		total = total.merge(_transformada_hasta(mallas[i], raiz) * mallas[i].get_aabb())
	return total


## Cuanto hay que subir un modelo para que su base quede en su propio origen.
##
## Da cero cuando ya esta bien apoyado. Los modelos de KayKit no siguen una sola
## convencion: la mayoria trae el origen en la base, pero catorce lo traen en el
## centro, y esos se hunden hasta medio metro en el piso si se los coloca tal
## cual.
static func apoyo_de(raiz : Node3D) -> float:
	var caja := caja_de(raiz)
	return 0.0 if caja.size == Vector3.ZERO else -caja.position.y


static func _juntar_mallas(nodo : Node, salida : Array[VisualInstance3D]) -> void:
	if nodo is VisualInstance3D:
		salida.append(nodo)
	for hijo in nodo.get_children():
		_juntar_mallas(hijo, salida)


## Acumula las transformadas locales desde una malla hasta la raiz del modelo.
static func _transformada_hasta(nodo : Node3D, raiz : Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var actual := nodo
	while actual != null:
		t = actual.transform * t
		if actual == raiz:
			break
		actual = actual.get_parent() as Node3D
	return t
