@tool
extends EditorScript

## Regenera ui/tema/tema.tres desde los sprites del pack de UI.
##
## Se corre desde el editor con Archivo > Ejecutar (Ctrl+Shift+X) con este script
## abierto. No se ejecuta durante el juego.
##
## Toda la logica esta en ConstructorTema.gd; esto es solo el boton. Si falta
## algun sprite, primero hay que correr herramientas/escalar_sprites_ui.py (desde
## la raiz del repo) y dejar que el editor importe los PNG.

const ConstructorTema := preload("res://herramientas/ConstructorTema.gd")


func _run() -> void:
	var error := ConstructorTema.guardar()
	if error == OK:
		print("GenerarTema: %s regenerado." % ConstructorTema.RUTA_TEMA)
