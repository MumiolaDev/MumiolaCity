extends Node

## La experiencia y el nivel de cada habilidad del jugador.
##
## Guarda xp y **nunca** el nivel: el nivel se deriva de la xp contra la curva de
## la habilidad. Guardar los dos seria tener dos fuentes para un solo hecho, y el
## dia que una se actualice sin la otra el jugador tendria nivel 7 con la xp de
## nivel 3 y nadie sabria cual creer.
##
## Ninguna cadena literal de habilidad se escribe aca: los ids salen de
## Habilidades, que es lo que evita que "Cocina" y "cocina" convivan (D4).

## Se emite con cada ganancia, incluso si no hubo cambio de nivel.
signal xp_ganada(habilidad : StringName, cantidad : int, total : int)
## Se emite una vez por cada nivel alcanzado, no una sola por la ganancia: si un
## crafteo da para subir tres niveles, quien escuche se entera de los tres.
signal nivel_subido(habilidad : StringName, nivel : int)

const CARPETA := "res://data/habilidades"

var _xp : Dictionary = {}            # StringName -> int
var _definiciones : Dictionary = {}  # StringName -> SkillDefinition


func _ready() -> void:
	recargar()


## Vuelve a leer las definiciones de habilidad del disco.
func recargar() -> void:
	_definiciones.clear()
	var dir := DirAccess.open(CARPETA)
	if dir == null:
		push_error("SkillManager: no se pudo abrir %s." % CARPETA)
		return

	for archivo in dir.get_files():
		# En una build exportada los .tres llegan como .tres.remap.
		var nombre := archivo.trim_suffix(".remap")
		if not nombre.ends_with(".tres"):
			continue
		var recurso := ResourceLoader.load(CARPETA.path_join(nombre))
		if recurso is SkillDefinition:
			_definiciones[recurso.id] = recurso

	for id in Habilidades.TODAS:
		if not _definiciones.has(id):
			push_warning("SkillManager: falta la definicion de '%s'." % id)


## Devuelve la definicion de una habilidad, o null.
func definicion(id : StringName) -> SkillDefinition:
	return _definiciones.get(id, null)


## Devuelve la xp acumulada de una habilidad.
func xp_de(id : StringName) -> int:
	return _xp.get(id, 0)


## Devuelve el nivel actual de una habilidad.
##
## Se calcula, no se guarda. Una habilidad sin definicion devuelve 0 y no 1, para
## que la diferencia entre "no la tiene todavia" y "esta en el primer nivel" sea
## visible en vez de confundirse.
func nivel_de(id : StringName) -> int:
	var def := definicion(id)
	return 0 if def == null else def.nivel_para_xp(xp_de(id))


## Devuelve cuanto lleva del nivel actual y cuanto mide ese nivel, para una barra
## de progreso. Cero y cero al llegar al maximo.
func progreso_de(id : StringName) -> Vector2i:
	var def := definicion(id)
	return Vector2i.ZERO if def == null else def.progreso_en_nivel(xp_de(id))


## Suma experiencia y avisa de los niveles que se hayan alcanzado.
func agregar_xp(id : StringName, cantidad : int) -> void:
	if cantidad <= 0:
		return
	if not Habilidades.existe(id):
		push_error("SkillManager: '%s' no es una habilidad conocida." % id)
		return

	var antes := nivel_de(id)
	_xp[id] = xp_de(id) + cantidad
	var despues := nivel_de(id)

	xp_ganada.emit(id, cantidad, _xp[id])
	for n in range(antes + 1, despues + 1):
		nivel_subido.emit(id, n)


## Devuelve si la habilidad llega a ese nivel.
##
## Existe para que quien valide una receta no tenga que escribir la comparacion
## cada vez, y sobre todo para que el criterio viva en un solo lugar el dia que
## deje de ser un simple mayor o igual.
func alcanza_nivel(id : StringName, nivel : int) -> bool:
	return nivel_de(id) >= nivel


## Devuelve el nivel de todas las habilidades con contenido.
func todos_los_niveles() -> Dictionary:
	var salida := {}
	for id in Habilidades.TODAS:
		salida[id] = nivel_de(id)
	return salida


## Borra todo el progreso.
func reiniciar() -> void:
	_xp.clear()


## Vuelca la xp a un diccionario serializable. Solo la xp: el nivel se recalcula.
func to_dict() -> Dictionary:
	var salida := {}
	for id in _xp:
		salida[String(id)] = _xp[id]
	return salida


## Reemplaza la xp con lo que diga el diccionario.
func from_dict(d : Dictionary) -> void:
	_xp.clear()
	for clave in d:
		var id := StringName(clave)
		if Habilidades.existe(id):
			_xp[id] = int(d[clave])
		else:
			push_warning("SkillManager: el guardado trae '%s', que ya no es una habilidad." % id)
