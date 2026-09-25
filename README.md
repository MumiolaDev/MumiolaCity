# MumiolaCity

Sandbox isométrico en línea al estilo Habbo: salas que arma cada jugador y un mundo donde casi todo lo que hay se puede usar, con el grano fino de un simulador. La idea es poner primero las interacciones y los sistemas de un mundo real, y diseñar después las mecánicas de juego sobre ellos. La economía de jugadores del diseño original está archivada; ver `docs/GDD.md` §9.

- [`docs/GDD.md`](docs/GDD.md) — documento de diseño general (pilares, loop, habilidades, economía, arte, arquitectura técnica, roadmap).
- [`docs/SCRIPTS.md`](docs/SCRIPTS.md) — mapa de todos los scripts principales, su función y cómo interactúan entre sí, ordenados por fase de implementación (también publicado como [artefacto navegable](https://claude.ai/code/artifact/5f914cd8-0d3b-437a-981a-0f18a4bb0a82)).
- [`docs/SISTEMAS.md`](docs/SISTEMAS.md) — cómo se comunican los sistemas entre sí: las cuatro capas y la regla de dirección, el grafo de dependencias, los seis flujos de extremo a extremo, dónde vive cada dato, las diecisiete decisiones de arquitectura (D1–D17) y los hallazgos sobre el balance de la economía (también publicado como [artefacto navegable](https://claude.ai/code/artifact/d03673ae-eb6b-4882-8500-aced5957bd82)).
- [`docs/CLASES.md`](docs/CLASES.md) — referencia de las 44 clases a implementar: de qué hereda cada una, qué campos exporta, qué señales emite, qué métodos ofrece y qué invariantes tiene que respetar.
- [`docs/IMPLEMENTACION.md`](docs/IMPLEMENTACION.md) — checklist de implementación script por script: qué definir, qué construir y cómo verificar antes de pasar al siguiente.
- [`mumiola-city/data/objetos/items.json`](mumiola-city/data/objetos/items.json) — diccionario fuente de ítems del MVP (fuente de la futura base de datos de ítems en Godot).
- [`mumiola-city/data/objetos/lista_items.md`](mumiola-city/data/objetos/lista_items.md) — lista legible de esos mismos ítems, por categoría, con una nota de en qué sistema participa cada uno.

## El proyecto

El proyecto de Godot vive en [`mumiola-city/`](mumiola-city/). Se abre con Godot 4.7 y arranca en el menú de inicio, `escenas/menu/MenuInicio.tscn`. Correr `escenas/mundo/Mundo.tscn` directo (F6) entra a la plaza con un perfil de desarrollo que no se guarda.

```
mumiola-city/
  nucleo/       Definiciones compartidas sin escena ni estado (Errores, Comandos, ServidorLocal)
  autoloads/    Managers globales (Consola, Servidor, GameManager, SaveManager...)
  data/         Items, recetas, habilidades, MeshLibrary del escenario, y salas:
                las publicas y las plantillas de forma, como documentos JSON
  escenas/
    menu/       El menu de inicio
    mundo/      IsoGrid, RoomController, el mundo y la escena generica de sala
    personaje/  Avatar y animaciones
    objetos/    WorldObject y sus recursos
    ui/         La interfaz; componentes/ tiene Ventana y Dialogo
    test/       Las pruebas, una por script, que se cuelgan de Mundo
  ui/           El tema (generado) y las fuentes
  arte/         Modelos glTF por familia y los sprites del pack de UI
  herramientas/ Generadores que corren en el editor (tema, iconos, catalogo)

herramientas/   Generadores en Python: catalogo, plantillas de sala, sprites de UI
```

Repo privado, uso personal de respaldo del diseño.
