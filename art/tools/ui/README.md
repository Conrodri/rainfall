# Icônes items A

17 builders 3D autonomes, dans l'ordre du brief. La bibliothèque ui_lib.py ne requiert que Blender. finalize.py utilise exclusivement Pillow pour recadrer, réduire et composer la planche de contrôle.

Exécution depuis la racine du projet, PowerShell :

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python art/tools/ui/items_a.py
& 'C:\Users\const\AppData\Local\Python\bin\python.exe' -I art/tools/ui/finalize.py --contact
```

Sous-ensemble : ajouter `-- antidote flocon` à la première commande. Chaque lancement sauvegarde dans items_a.blend les scènes des items sélectionnés ; relancer sans sélection pour retrouver les 17 scènes.

Le Python isolé ignore PYTHONPATH : finalize.py ajoute explicitement art/tools/vendor à sys.path. Aucun Pillow n'est chargé dans Blender.

Livrables : rendus RGBA 512, icônes RGBA 256 à marge minimale de 12 pixels, blend multiscène, planche comparant 256 et 64 pixels. Le JSON de validation vérifie dimensions, alpha, centrage et empreintes distinctes. Les 17 PNG ont aussi été inspectés visuellement.
