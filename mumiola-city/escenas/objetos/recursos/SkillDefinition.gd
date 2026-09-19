class_name SkillDefinition
extends Resource

## Una habilidad: como nombrarla, como progresa y que desbloquea.
##
## El id siempre sale de Habilidades; nombre_display es el unico lugar donde la
## habilidad lleva tilde y mayuscula (D4).

@export var id : StringName = &""
## "Agricultura", con tilde si corresponde. Solo para mostrarle al jugador.
@export var nombre_display : String = ""
@export_multiline var descripcion : String = ""
@export_enum("recoleccion", "produccion", "soporte") var familia : String = "produccion"
@export var icono : Texture2D

@export_group("Progresion")
@export var nivel_maximo : int = 50

## La forma de la curva de experiencia, normalizada entre 0 y 1.
##
## Es un recurso Curve a proposito: se balancea arrastrando puntos en el
## inspector, sin recompilar y sin que nadie tenga que discutir un exponente. Si
## queda en null se usa una progresion cuadratica, que es una curva razonable y
## evita que una habilidad sin curva asignada rompa el calculo.
@export var curva_xp : Curve
@export var xp_total_al_maximo : int = 100000

## Que se desbloquea a cada nivel: {nivel: int -> Array[StringName]}.
##
## Es la excepcion al tipado estricto del proyecto, y esta documentada: Godot 4
## no exporta bien un Dictionary con tipos en clave y valor, asi que se declara
## la forma aca y se valida al cargar el catalogo.
@export var desbloqueos : Dictionary = {}


## Devuelve la xp acumulada que hace falta para alcanzar un nivel.
##
## La trampa de Curve es que devuelve valores entre 0 y 1, asi que hay que
## escalarla: la formula real es sample(nivel / nivel_maximo) * xp_total.
func xp_para_nivel(nivel : int) -> int:
	var n := clampi(nivel, 1, nivel_maximo)
	var t := float(n - 1) / float(maxi(nivel_maximo - 1, 1))
	if curva_xp != null:
		return int(round(curva_xp.sample(t) * xp_total_al_maximo))
	return int(round(t * t * xp_total_al_maximo))


## Devuelve que nivel corresponde a una xp acumulada.
##
## Recorre los niveles en vez de invertir la curva: invertir una Curve arbitraria
## no tiene solucion cerrada, y con cincuenta niveles el bucle es gratis.
func nivel_para_xp(xp : int) -> int:
	var nivel := 1
	for n in range(2, nivel_maximo + 1):
		if xp < xp_para_nivel(n):
			break
		nivel = n
	return nivel


## Devuelve cuanta xp falta para el nivel siguiente, y cuanta lleva el actual.
##
## Es lo que necesita una barra de progreso, y calcularlo aca evita que cada
## interfaz vuelva a deducirlo y se equivoque distinto.
func progreso_en_nivel(xp : int) -> Vector2i:
	var nivel := nivel_para_xp(xp)
	if nivel >= nivel_maximo:
		return Vector2i(0, 0)
	var base := xp_para_nivel(nivel)
	return Vector2i(xp - base, xp_para_nivel(nivel + 1) - base)


## Devuelve todo lo desbloqueado hasta ese nivel, inclusive.
func desbloqueos_hasta(nivel : int) -> Array[StringName]:
	var salida : Array[StringName] = []
	for clave in desbloqueos:
		if int(clave) <= nivel:
			for x in desbloqueos[clave]:
				salida.append(StringName(x))
	return salida
