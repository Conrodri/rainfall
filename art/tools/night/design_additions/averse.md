# Averse — ajouts de design (agent kit, 22/10/2026), à fusionner dans Design_Personnages §2.1
- Eau de départ 50, conservée entre étages et dans la sauvegarde de run (`save_state`).
- Pluie : rain_intensity du profil < 0,05 = sec (×0) ; sinon multiplicateur 0,5 + intensité borné 0,5-1,5 ; sans AmbianceManager ×1. Eau de carte lue sur les cases « , » et « ~ ».
- Goutte-lame (auto) : coef figé au tir, 13 u/s ; élément « frost » pour tous les sorts. Impact frame 3 (attack).
- Vague : cône 60°, visée souris/stick sinon paquet le plus dense ; recul réel 1,5 u × masse (poussée en plus du plafond). Impact frame 3 (wave).
- Flaque-miroir : portée de pose 7 u, ciblage par densité, trempe rafraîchie toutes les 0,25 s. Impact frame 2 (cast).
- Crue (ultime) : trempe aussi ; recul 3 u × masse (pas les boss) ; coef = max(0,1 × eau, 4) ; rayon = 4 + 0,02 × eau. Impact frame 5 (crue / cast_ult).
- Trébuchement (amphore ≥ 80) : roulade 1,5 u (0,125 s, invulnérabilité réduite), anim stumble, sans fantômes, puis 0,25 s à vitesse ×0,6.
- Stats : hitbox 0,5 u, armure 0. Lumières averse_water / averse_wave / averse_crue, lumière joueur cyan froid (`CharacterData.light_color` / `light_core_color`).
- Niveau d'eau lisible par l'énergie du masque _e de l'amphore (20 paliers).
