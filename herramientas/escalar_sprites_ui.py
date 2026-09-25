#!/usr/bin/env python3
"""Copia los sprites del pack de UI al proyecto, escalados x2 sin suavizar.

Uso:
    python3 herramientas/escalar_sprites_ui.py <carpeta Sprites del pack>

La carpeta es la de Complete_UI_Essential_Pack_Free/01_Flat_Theme/Sprites,
descomprimida del .7z. Escribe en mumiola-city/arte/sprites/UI/flat_x2/, con el
prefijo "UI_Flat_" quitado: "UI_Flat_Button01a_1.png" -> "Button01a_1.png".

Por que x2 y en disco, y no escalado en el juego: los sprites miden 16-32 px y a
1280x720 se ven diminutos. Un StyleBoxTexture no tiene escala propia, y escalar
toda la interfaz con el stretch del proyecto moveria las cuentas de posicion que
ya hacen el menu contextual y la paleta. Duplicar cada pixel una vez, al copiar,
deja el pixel art nitido y no toca nada mas.

Es idempotente: volver a correrlo pisa lo que haya.
"""

import sys
from pathlib import Path

from PIL import Image

ESCALA = 2
PREFIJO = "UI_Flat_"
DESTINO = Path(__file__).resolve().parent.parent / "mumiola-city" / "arte" / "sprites" / "UI" / "flat_x2"


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 1

    origen = Path(sys.argv[1])
    archivos = sorted(origen.glob("*.png"))
    if not archivos:
        print(f"No hay PNG en {origen}.")
        return 1

    DESTINO.mkdir(parents=True, exist_ok=True)
    for archivo in archivos:
        imagen = Image.open(archivo).convert("RGBA")
        grande = imagen.resize((imagen.width * ESCALA, imagen.height * ESCALA), Image.NEAREST)
        nombre = archivo.name.removeprefix(PREFIJO)
        grande.save(DESTINO / nombre)

    escritos = len(list(DESTINO.glob("*.png")))
    print(f"{len(archivos)} sprites leidos, {escritos} en {DESTINO}.")
    return 0 if escritos >= len(archivos) else 1


if __name__ == "__main__":
    sys.exit(main())
