"""Musique Rainfall : sequenceur + synthese, boucles parfaites (reverb a convolution circulaire).
4 stems synchronises par carte (base / tension / drive / climax), un theme de boss par carte, un menu.
Harmonie ecrite (progressions + melodies en notation 'degre:duree'), pas aleatoire.
uv run --with numpy --with scipy python art/tools/audio/gen_music.py [--only terrasses_noyees|boss|menu] [--out DIR]
Sorties : game/assets/audio/music/music_<carte>_<stem>_01.ogg, music_boss_<carte>_01.ogg, music_menu_01.ogg
"""
import argparse
import json
import re
from pathlib import Path
import numpy as np
import audio_common as ac
import synth_lib as sl

SR = ac.SR
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game' / 'assets' / 'audio' / 'music'
M = sl.mtof
PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
Q = {'': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'maj7': [0, 4, 7, 11], 'dim': [0, 3, 6],
     '5': [0, 7], 'sus': [0, 5, 7], 'm9': [0, 3, 7, 10, 14], 'add9': [0, 4, 7, 14]}
AEOL = [0, 2, 3, 5, 7, 8, 10]
DOR = [0, 2, 3, 5, 7, 9, 10]
PHRY = [0, 1, 3, 5, 7, 8, 10]


def parse_chord(s):
    m = re.match(r'^([A-G])([#b]?)(.*)$', s)
    r = PC[m.group(1)] + (1 if m.group(2) == '#' else -1 if m.group(2) == 'b' else 0)
    return r % 12, Q[m.group(3)]


def parse_bar(s, scale, root, shift=0):
    """'5:2 3:1 7#:1' -> [(beat, midi, len)] ; verifie 4 temps."""
    out, pos = [], 0.0
    for tok in s.split():
        d, ln = tok.split(':')
        ln = float(ln)
        if d != 'r':
            m = re.match(r'^(-?\d+)([#b]?)$', d)
            deg = int(m.group(1)) + shift
            acc = 1 if m.group(2) == '#' else -1 if m.group(2) == 'b' else 0
            octv, step = divmod(deg - 1, 7)
            out.append((pos, root + octv * 12 + scale[step] + acc, ln))
        pos += ln
    assert abs(pos - 4) < 1e-6, (s, pos)
    return out


# ------------------------------------------------------------------ partitions ----
CFG = {
    # D eolien, 72 BPM : piano feutre, harpe, cloches
    'terrasses_noyees': dict(
        bpm=72, scale=AEOL, mel_root=62, mel_inst='piano', arp_inst='harp', bell=True, pad_cut=1500, rt60=3.4, rev_bright=.3,
        taiko_f0=50, perc='soft',
        chords={'A': 'Dm Bb F C Dm Gm Bb A', 'B': 'Bb F Gm Dm Bb C A7 A'},
        mel={'A': ['5:2 3:1 5:1', '6:2 5:1 3:1', '3:1.5 5:.5 7:1 8:1', '7:2 5:1 4:1', '3:2 5:1 8:1', '6:2 8:1 6:1', '5:1 6:1 8:2', '5:1 7#:1 9:2'],
             'A2': ['8:1.5 7:.5 5:2', '6:1 8:1 10:2', '10:2 8:1 7:1', '7:1 5:1 4:2', '5:2 3:1 1:1', '4:1 6:1 8:2', '6:2 5:1 3:1', '5:2 7#:1 9:1'],
             'B': ['8:2 6:2', '7:1 8:1 10:2', '11:2 10:1 8:1', '10:2 8:1 5:1', '6:1 8:1 10:1 8:1', '9:2 7:1 9:1', '11:1 9:1 7#:2', '5:3 r:1']},
        order=[('A', 'A'), ('A', 'A2'), ('B', 'B'), ('A', 'A')]),
    # E dorien, 64 BPM : flute, cordes pincees, pads vaporeux
    'foret_brume': dict(
        bpm=64, scale=DOR, mel_root=64 + 12, mel_inst='flute', arp_inst='pluck', bell=False, pad_cut=1100, rt60=3.8, rev_bright=.2,
        taiko_f0=46, perc='wood',
        chords={'A': 'Em A Em D Em A G D', 'B': 'Bm G D A Bm G A Em'},
        mel={'A': ['5:2 3:1 5:1', '4:1 6:1 8:2', '7:1.5 5:.5 3:2', '2:1 4:1 7:2', '8:2 7:1 5:1', '6:2 4:1 6:1', '5:1 7:1 9:2', '7:2 4:1 2:1'],
             'B': ['5:2 7:1 9:1', '8:1 7:1 5:2', '4:2 7:2', '6:3 r:1', '9:2 7:1 5:1', '3:1 5:1 7:1 5:1', '4:1 6:1 8:1 6:1', '5:2 3:1 1:1']},
        order=[('A', 'A'), ('A', 'A+'), ('B', 'B'), ('A', 'A')]),
    # Do phrygien, 84 BPM : metal, drones, cordes graves
    'cite_rouille': dict(
        bpm=84, scale=PHRY, mel_root=48, mel_inst='cello', arp_inst='pluck', bell=True, pad_cut=1000, rt60=2.8, rev_bright=.45,
        taiko_f0=44, perc='metal',
        chords={'A': 'Cm Db Cm Bbm Cm Db Ab Bbm', 'B': 'Ab Bbm Db Cm Ab Db Bbm Cm', 'T': 'Cm Db Bbm Cm'},
        mel={'A': ['1:2 3:1 5:1', '2:2 4:1 6:1', '5:2 3:1 1:1', '7:2 4:1 2:1', '1:1 3:1 5:1 8:1', '9:2 8:1 7:1', '6:2 8:1 10:1', '7:2 4:1 2:1'],
             'B': ['10:2 8:1 6:1', '11:2 9:1 7:1', '9:1 11:1 13:2', '12:2 10:1 8:1', '13:2 12:1 10:1', '11:2 9:2', '14:1 13:1 11:2', '12:2 10:1 8:1'],
             'T': ['1:4', '2:4', '4:2 2:2', '1:4']},
        order=[('A', 'A'), ('A', 'A+'), ('B', 'B'), ('A', 'A'), ('T', 'T')]),
}
BOSS = {
    'terrasses_noyees': dict(
        bpm=112, scale=AEOL, mel_root=62, mel_inst='brass', arp_inst='harp', bell=True, pad_cut=1400, rt60=3.0, rev_bright=.35, taiko_f0=48,
        perc='soft', extra='water',
        chords={'A': 'Dm Dm Bb C Dm Dm Gm A', 'B': 'Bb F Gm A Bb F A A'},
        mel={'A': ['1:1 1:.5 3:.5 5:1 3:1', '1:1 1:.5 3:.5 5:1 6:1', '6:1.5 5:.5 3:1 1:1', '7:1.5 5:.5 4:1 2:1', '8:1 8:.5 7:.5 5:1 3:1',
                   '8:1 10:.5 8:.5 7:2', '6:1 8:1 6:1 4:1', '5:1 7#:1 9:1 7#:1'],
             'B': ['10:2 8:1 6:1', '7:1 8:1 10:2', '11:2 10:1 8:1', '9:1 7#:1 5:2', '6:1 8:1 10:1 11:1', '12:2 10:1 8:1', '9:2 7#:1 9:1', '5:1 7#:1 9:2']},
        order=[('A', 'A'), ('A', 'A'), ('B', 'B'), ('A', 'A'), ('B', 'B'), ('A', 'A')]),
    'foret_brume': dict(
        bpm=120, scale=DOR, mel_root=64, mel_inst='reed', arp_inst='pluck', bell=False, pad_cut=1000, rt60=3.0, rev_bright=.2, taiko_f0=44,
        perc='wood', extra='wood',
        chords={'A': 'Em Em C D Em Em F D', 'B': 'C D Em Em C D F B'},
        mel={'A': ['1:1 1:.5 3:.5 5:1 3:1', '5:1 3:.5 1:.5 2:1 3:1', '3:1 6b:1 5:1 3:1', '2:1 4:1 7:1 4:1', '8:1 8:.5 7:.5 5:1 3:1', '8:1 9:.5 8:.5 5:2',
                   '2b:1 4:1 6b:2', '7:1 4:1 2:2'],
             'B': ['10:2 8:1 6b:1', '9:2 7:1 4:1', '8:1 10:1 12:2', '10:2 8:1 5:1', '6b:1 8:1 10:1 8:1', '9:1 7:1 4:1 7:1', '9b:1 8:1 6b:2', '7#:1 9:1 12:2']},
        order=[('A', 'A'), ('A', 'A+'), ('B', 'B'), ('A', 'A'), ('B', 'B'), ('A', 'A+'), ('B', 'B')]),
    'cite_rouille': dict(
        bpm=126, scale=PHRY, mel_root=48, mel_inst='cello', arp_inst='pluck', bell=True, pad_cut=900, rt60=2.6, rev_bright=.5, taiko_f0=42,
        perc='metal', extra='bells',
        chords={'A': 'Cm Db Cm Db Cm Bbm Db Cm', 'B': 'Ab Bbm Db Cm Ab Db Bbm Gdim'},
        mel={'A': ['1:1 1:.5 3:.5 2:1 1:1', '2:1 2:.5 4:.5 6:1 4:1', '1:1 1:.5 3:.5 5:1 3:1', '2:2 4:1 2:1', '8:1 8:.5 7:.5 5:1 3:1', '7:1 7:.5 4:.5 2:1 4:1',
                   '9:2 8:1 6:1', '5:1 3:1 1:2'],
             'B': ['10:2 8:1 6:1', '11:2 9:1 7:1', '13:2 11:1 9:1', '12:2 10:1 8:1', '13:2 12:1 10:1', '11:2 9:2', '14:1 13:1 11:2', '12:1 14:1 16:2']},
        order=[('A', 'A'), ('A', 'A'), ('B', 'B'), ('A', 'A'), ('B', 'B'), ('A', 'A'), ('B', 'B')]),
}
Q['dim'] = [0, 3, 6]
Q['Gdim'] = [0, 3, 6]
_old_parse = parse_chord


def parse_chord(s):  # 'Gdim' -> quality 'dim'
    return _old_parse(s)


MENU = dict(
    bpm=60, scale=AEOL, mel_root=69, pad_cut=900, rt60=2.4,
    chords={'A': 'Am F C G Am F E Am', 'B': 'F C G Am F C E E'},
    mel={'A': ['5:2 3:1 1:1', '6:2 5:1 3:1', '5:2 3:1 5:1', '7:1 4:1 2:2', '3:2 5:1 8:1', '8:2 6:1 3:1', '5:1 7#:1 5:1 2:1', '1:4'],
         'B': ['6:2 8:2', '5:2 3:2', '4:2 7:2', '8:2 5:2', '6:1 8:1 10:2', '10:2 8:1 5:1', '7#:2 5:1 2:1', '5:4']},
    order=[('A', 'A'), ('B', 'B'), ('A', 'A')])


# ------------------------------------------------------------------ structure ----
class Song:
    def __init__(self, cfg):
        self.cfg = cfg
        self.bar = int(round(240.0 / cfg['bpm'] * SR))
        assert abs(240.0 / cfg['bpm'] * SR - self.bar) < 1e-6
        self.bars = []
        for si, (ck, mk) in enumerate(cfg['order']):
            shift = 7 if mk.endswith('+') else 0
            mk0 = mk.rstrip('+')
            chords = cfg['chords'][ck].split()
            mel = cfg['mel'][mk0]
            for i, cname in enumerate(chords):
                self.bars.append(dict(sec=si, local=i, name=cname, chord=parse_chord(cname),
                                      mel=parse_bar(mel[i], cfg['scale'], cfg['mel_root'], shift), key=ck, nsec=len(chords)))
        self.n_bars = len(self.bars)
        self.N = self.n_bars * self.bar
        self.dur = self.N / SR

    def t(self, b, beat=0.0):
        return int(round((b * 4 + beat) * self.bar / 4))

    def sec(self, beats):
        return beats * self.bar / 4 / SR

    def runs(self):
        """Groupes de mesures consecutives au meme accord."""
        out, i = [], 0
        while i < self.n_bars:
            j = i
            while j + 1 < self.n_bars and self.bars[j + 1]['name'] == self.bars[i]['name'] and self.bars[j + 1]['sec'] == self.bars[i]['sec']:
                j += 1
            out.append((i, j - i + 1))
            i = j + 1
        return out


class Stem:
    def __init__(self, N):
        self.dry = np.zeros((N, 2), dtype=np.float32)
        self.send = np.zeros((N, 2), dtype=np.float32)

    def add(self, song, bar, beat, x, g=1.0, pan=0.0, send=.3, dry=1.0):
        s = song.t(bar, beat)
        if dry:
            sl.put(self.dry, s, x, g * dry, pan)
        if send:
            sl.put(self.send, s, x, g * send, pan)

    def render(self, rev, wet=1.0):
        return self.dry.astype(np.float64) + rev.circular(self.send.astype(np.float64)) * wet


def voicing(root_pc, ivs, lo=53):
    return sorted(lo + ((root_pc + iv - lo) % 12) for iv in ivs[:4])


def bass_midi(root_pc, base=36):
    return base + ((root_pc - base) % 12)


_cache = {}


def cached(key, fn):
    if key not in _cache:
        _cache[key] = fn()
    return _cache[key]


def melody_note(inst, midi, dur_s, vel, rng):
    f = float(M(midi))
    if inst == 'piano':
        return sl.piano(f, dur_s, vel, rng)
    if inst == 'flute':
        return sl.flute(f, dur_s, vel, rng)
    if inst == 'cello':
        return sl.cello(f, dur_s, vel, rng)
    if inst == 'reed':
        return sl.reed(f, dur_s, vel, rng)
    if inst == 'brass':
        return sl.brass(f, dur_s, vel, .08)
    if inst == 'harp':
        return sl.harp(f, dur_s, vel, rng)
    raise ValueError(inst)


def arp_note(inst, midi, rng, vel=.6):
    f = float(M(midi))
    if inst == 'harp':
        return sl.harp(f, 1.4, vel, rng)
    return sl.pluck(f, .5, rng, tau=.4, bright=.6)


# ------------------------------------------------------------------ couches ----
def layer_base(song, rng, vel_mul=1.0):
    c = song.cfg
    st = Stem(song.N)
    for (b0, nb) in song.runs():
        bar = song.bars[b0]
        rpc, ivs = bar['chord']
        notes = voicing(rpc, ivs)
        pad = sl.pad_chord([M(n) for n in notes], song.sec(4 * nb), rel=2.4, att=1.6, cut=c['pad_cut'], rng=rng)
        st.add(song, b0, 0, pad, .55, 0, send=.55)
        if c['mel_inst'] == 'flute' or c.get('extra') == 'wood':
            pad2 = sl.pad_chord([M(n + 12) for n in notes[:3]], song.sec(4 * nb), rel=3.0, att=2.2, cut=c['pad_cut'] * 1.6, rng=rng, spread=11)
            st.add(song, b0, 0, pad2, .28, 0, send=.7)
        bn = bass_midi(rpc)
        st.add(song, b0, 0, sl.bass_sine(float(M(bn)), song.sec(4 * nb) * .96), .55, 0, send=.2)
    for b, bar in enumerate(song.bars):
        # melodie
        for (beat, midi, ln) in bar['mel']:
            vel = (.55 + .12 * (bar['key'] == 'B')) * vel_mul
            x = melody_note(c['mel_inst'], midi, song.sec(ln) * .95, vel, rng)
            st.add(song, b, beat + rng.uniform(-.012, .012), x, .75, rng.uniform(-.2, .2), send=.5)
        # arpege de harpe / cordes pincees : une mesure sur deux, doux
        if b % 2 == 1 or bar['key'] == 'B':
            rpc, ivs = bar['chord']
            tones = [72 + ((rpc + iv - 72) % 12) for iv in ivs[:3]]
            pat = [0, 1, 2, 1, 2, 1, 2, 1] if bar['key'] != 'B' else [0, 1, 2, 1, 0, 1, 2, 1]
            for i, k in enumerate(pat):
                if bar['mel'] and any(abs(m - tones[k]) < 2 and beat <= i / 2 < beat + ln for beat, m, ln in bar['mel']):
                    continue
                x = arp_note(c['arp_inst'], tones[k] - (12 if i % 4 == 3 else 0), rng, .45)
                st.add(song, b, i * .5, x, .35, -.5 + .14 * i, send=.5)
        # cloche : debut de chaque groupe de 4 mesures
        if c['bell'] and b % 4 == 0:
            rpc, ivs = bar['chord']
            n_ = 84 + ((rpc + ivs[2] - 84) % 12)
            if c['perc'] == 'metal':
                x = sl.lp(sl.bell(float(M(n_ - 24)), 5.0, rng=rng, tau=2.2, ratios=[(1, 1, 1), (1.18, .7, .9), (1.47, .6, .6), (2.09, .5, .45), (2.76, .35, .35)]), 1800, 2)
                st.add(song, b, 0, x, .35, .3, send=.8)
            else:
                st.add(song, b, 0, sl.bell(float(M(n_)), 5.0, rng=rng, tau=2.8), .28, .3, send=.8)
    return st


def drum_hit(kind, rng, c, vel):
    if kind == 'taiko':
        return cached(('taiko', round(vel, 2), c['taiko_f0']), lambda: sl.taiko(vel, np.random.default_rng(5), c['taiko_f0']))
    if kind == 'tom':
        return cached(('tom', round(vel, 2), c['perc']), lambda: sl.tom(95 if c['perc'] != 'wood' else 150, vel, np.random.default_rng(6)))
    raise ValueError


def layer_tension(song, rng):
    c = song.cfg
    st = Stem(song.N)
    for b, bar in enumerate(song.bars):
        rpc, ivs = bar['chord']
        st.add(song, b, 0, drum_hit('taiko', rng, c, .85), .7, 0, send=.45)
        st.add(song, b, 2.5, drum_hit('taiko', rng, c, .55), .5, 0, send=.45)
        if b % 4 == 3:
            st.add(song, b, 3, drum_hit('tom', rng, c, .6), .5, -.3, send=.4)
            st.add(song, b, 3.5, drum_hit('tom', rng, c, .75), .55, .3, send=.4)
        for i in range(8):
            v = [.5, .22, .34, .22, .45, .22, .34, .26][i]
            x = sl.shaker(v * (1 if c['perc'] != 'wood' else .9), np.random.default_rng(100 + i + (b % 3) * 8), lo=5500 if c['perc'] != 'metal' else 6500)
            st.add(song, b, i * .5, x, .55, [-.4, .3, -.2, .45][i % 4], send=.3)
        bn = bass_midi(rpc, 48)
        for beat in (1.5, 3.5):
            x = sl.pluck(float(M(bn)), .4, rng, tau=.3, bright=.35)
            st.add(song, b, beat, x, .5, 0, send=.3)
        if c['perc'] == 'metal':
            st.add(song, b, 2, sl.hp(sl.metal_hit(float(M(bn + 24)), .6, np.random.default_rng(9 + b % 3), dur=.8), 700, 1), .35, .4, send=.5)
        elif c['perc'] == 'wood':
            st.add(song, b, 1, sl.pluck(float(M(bn + 31)), .2, rng, tau=.08, bright=1.0), .5, -.4, send=.3)
        else:
            if b % 2 == 0:
                st.add(song, b, 1, sl.bell(float(M(84 + (rpc - 84) % 12)), 2.0, rng=rng, tau=.8), .18, .3, send=.7)
    return st


def layer_drive(song, rng):
    c = song.cfg
    st = Stem(song.N)
    ost = [0, 0, 12, 0, 7, 0, 10, 0]
    for b, bar in enumerate(song.bars):
        rpc, ivs = bar['chord']
        bn = bass_midi(rpc, 36)
        third = ivs[1]
        for i in range(8):
            semi = ost[i]
            if semi == 10:
                semi = third + 7 if third == 3 else 10
            x = cached(('bass', bn + semi, round(song.sec(.5) * 1000)), lambda: sl.bass_saw(float(M(bn + semi)), song.sec(.5) * .85, 520, .8))
            st.add(song, b, i * .5, x, .62 if i % 2 == 0 else .45, 0, send=.15)
        # ostinato de cordes 3+3+2 (doubles croches)
        tones = [60 + ((rpc + iv - 60) % 12) for iv in ivs[:3]]
        seq = [0, 2, 1, 0, 2, 1, 0, 1]
        for i, pos in enumerate([0, .75, 1.5, 2, 2.75, 3.5, 1.0, 3.0]):
            x = cached(('stacc', tones[seq[i]] + (12 if i in (2, 5) else 0)), lambda: sl.string_stacc(float(M(tones[seq[i]] + (12 if i in (2, 5) else 0))), .16, .85))
            st.add(song, b, pos, x, .5 if i < 6 else .3, -.5 if i % 2 else .5, send=.3)
        # frappes : grosse caisse 1 & 3, toms 2 & 4
        st.add(song, b, 0, drum_hit('taiko', rng, c, .95), .8, 0, send=.4)
        st.add(song, b, 2, drum_hit('taiko', rng, c, .8), .65, 0, send=.4)
        st.add(song, b, 1, drum_hit('tom', rng, c, .8), .55, -.3, send=.4)
        st.add(song, b, 3, drum_hit('tom', rng, c, .85), .6, .3, send=.4)
        for i in range(16):
            v = .38 if i % 4 else .55
            st.add(song, b, i * .25, sl.shaker(v, np.random.default_rng(300 + i), dur=.06, lo=7000), .45, [-.5, .5][i % 2], send=.2)
        if c['perc'] == 'metal':
            st.add(song, b, 0.5, sl.hp(sl.metal_hit(float(M(bn + 12)), .9, np.random.default_rng(12 + b % 4), dur=.7), 400, 1), .45, 0, send=.5)
        # nappe dissonante (cluster : seconde + triton) toutes les 2 mesures
        if b % 2 == 0:
            cl = [M(bn + 24), M(bn + 25), M(bn + 30), M(bn + 31)]
            st.add(song, b, 0, sl.pad_chord(cl, song.sec(8), rel=1.2, att=2.5, cut=1400, rng=rng, spread=14), .22, 0, send=.5)
    return st


def layer_climax(song, rng):
    c = song.cfg
    st = Stem(song.N)
    for (b0, nb) in song.runs():
        bar = song.bars[b0]
        rpc, ivs = bar['chord']
        notes = voicing(rpc, ivs, 48) + [n + 12 for n in voicing(rpc, ivs, 53)[:3]]
        ch = sl.choir([M(n) for n in notes], song.sec(4 * nb), rel=2.2, att=1.3, rng=rng)
        st.add(song, b0, 0, ch, .55, 0, send=.6)
        st.add(song, b0, 0, sl.bass_sine(float(M(bass_midi(rpc, 24))), song.sec(4 * nb) * .97), .7, 0, send=.2)
    for b, bar in enumerate(song.bars):
        rpc, ivs = bar['chord']
        # theme en octaves (cuivres)
        for (beat, midi, ln) in bar['mel']:
            for off, g, pan in ((0, .45, .25), (-12, .35, -.25), (12, .22, 0)):
                x = sl.brass(float(M(midi + off)), song.sec(ln) * .96, .85, .1)
                st.add(song, b, beat, x, g, pan, send=.6)
        for beat in range(4):
            st.add(song, b, beat, drum_hit('taiko', rng, c, 1.0 if beat == 0 else .7), .85 if beat == 0 else .6, 0, send=.5)
        if b % 4 == 3:
            for k, bt in enumerate((2.5, 3, 3.25, 3.5, 3.75)):
                st.add(song, b, bt, drum_hit('tom', rng, c, .6 + .08 * k), .55, [-.4, .4][k % 2], send=.5)
        if bar['local'] == 0:
            st.add(song, b, 0, sl.cymbal(3.2, np.random.default_rng(60 + b), .9), .7, 0, send=.6)
        if bar['local'] == bar['nsec'] - 1:
            st.add(song, b, 0, sl.noise_swell(song.sec(4), np.random.default_rng(70 + b), 300, 8000), .5, 0, send=.5)
        if c['perc'] == 'metal' and b % 2 == 0:
            st.add(song, b, 0, sl.bell(float(M(bass_midi(rpc, 36) + 12)), 5.0, rng=rng, tau=2.4, ratios=[(1, 1, 1), (1.19, .7, .9), (1.42, .6, .7), (1.89, .5, .5), (2.52, .4, .4)]), .35, 0, send=.7)
    return st


def layer_boss_extra(song, rng, kind):
    st = Stem(song.N)
    for b, bar in enumerate(song.bars):
        rpc, ivs = bar['chord']
        bn = bass_midi(rpc, 36)
        if kind == 'water':
            # ecluses : grondement d eau (bruit filtre module) + notes de cuivre graves
            n = song.bar
            nz = sl.bp(rng.normal(size=n + 2000), 120, 1400, 2)[1000:1000 + n]
            env = np.sin(np.pi * np.arange(n) / n) ** 2
            st.add(song, b, 0, nz * env * .6, .35, rng.uniform(-.5, .5), send=.4)
            if b % 2 == 0:
                st.add(song, b, 0, sl.brass(float(M(bn)), song.sec(7.6), .9, .3), .45, 0, send=.5)
                st.add(song, b, 0, sl.brass(float(M(bn + ivs[2])), song.sec(7.6), .8, .3), .3, .3, send=.5)
        elif kind == 'wood':
            # tambours de troncs : toc sec creux sur croches irregulieres
            for beat in (0.75, 1.75, 2.75, 3.25):
                f = rng.choice([180, 220, 150])
                n = int(.3 * SR)
                t = np.arange(n) / SR
                x = np.sin(2 * np.pi * np.cumsum(f * (1 + .6 * np.exp(-t / .02))) / SR) * np.exp(-t / .07) + sl.resonator(rng.normal(size=n), 700, 6) * np.exp(-t / .02) * .4
                st.add(song, b, beat, x * .7, .6, rng.uniform(-.5, .5), send=.5)
            if b % 2 == 0:
                st.add(song, b, 0, sl.cello(float(M(bn + 12)), song.sec(7.5), .7, rng, att=.4), .35, 0, send=.5)
        elif kind == 'bells':
            if b % 2 == 0:
                tri = [(1, 1, 1.6), (1.19, .8, 1.2), (1.41, .7, 1.0), (1.42, .55, .9), (2.0, .6, .7), (2.83, .45, .5)]  # triton a 1.41 : dissonance
                x = sl.bell(float(M(bn + 12)), 5.5, rng=rng, tau=2.8, ratios=tri)
                st.add(song, b, 0, x, .55, 0, send=.8)
            if b % 4 == 2:
                tri2 = [(1, 1, 1.5), (1.06, .6, 1.2), (1.5, .6, 1.0), (2.0, .5, .7)]
                st.add(song, b, 0, sl.bell(float(M(bn + 6)), 5.0, rng=rng, tau=2.6, ratios=tri2), .4, .3, send=.8)
            notes = [M(bn + 12), M(bn + 19), M(bn + 24)]
            if b % 4 == 0:
                st.add(song, b, 0, sl.choir(notes, song.sec(15), rel=2.0, att=2.0, rng=rng), .35, 0, send=.7)
    return st


# ------------------------------------------------------------------ rendu ----
def finish_stem(x, rms_target, peak_db=-3.5, thr_db=-9):
    x = x - x.mean(0)
    g = 10 ** ((rms_target - ac.rms_db(x)) / 20)
    x = sl.soft_limit(x * g, thr_db, peak_db)
    pk = ac.peak_db(x)
    if pk > peak_db:
        x = x * 10 ** ((peak_db - pk) / 20)
    return x


def write_music(path, x, items, usage, loop=True, gain=0):
    ac.write_ogg(path, x, 6)
    items.append(dict(path=f'music/{path.name}', duration_s=round(len(x) / SR, 4), loop=loop, level='none', usage=usage, gain_db=gain,
                      peak_dbfs=round(ac.peak_db(x), 2), rms_dbfs=round(ac.rms_db(x), 2), samples=len(x)))
    print(path.name, round(len(x) / SR, 2), 's pk', round(ac.peak_db(x), 1), 'rms', round(ac.rms_db(x), 1),
          'seam', round(sl.loop_seam_stats(x), 2), flush=True)


STEM_RMS = dict(base=-23, tension=-25.5, drive=-25, climax=-24)


def render_map(carte, items, seed):
    c = CFG[carte]
    song = Song(c)
    rng = np.random.default_rng(1000 + sum(map(ord, carte)) + seed)
    rev = sl.Reverb(np.random.default_rng(7 + seed), rt60=c['rt60'], brightness=c['rev_bright'])
    print(carte, 'bars', song.n_bars, 'dur', round(song.dur, 2), flush=True)
    fns = dict(base=layer_base, tension=layer_tension, drive=layer_drive, climax=layer_climax)
    for name, fn in fns.items():
        st = fn(song, np.random.default_rng(rng.integers(1 << 30)))
        x = finish_stem(st.render(rev), STEM_RMS[name])
        write_music(OUT / f'music_{carte}_{name}_01.ogg', x, items, f'music.{carte}.{name} ({c["bpm"]} BPM, {song.n_bars} mesures)')
        del st, x


def render_boss(carte, items, seed):
    c = BOSS[carte]
    song = Song(c)
    rng = np.random.default_rng(2000 + sum(map(ord, carte)) + seed)
    rev = sl.Reverb(np.random.default_rng(17 + seed), rt60=c['rt60'], brightness=c['rev_bright'])
    print('boss', carte, 'bars', song.n_bars, 'dur', round(song.dur, 2), flush=True)
    mix = np.zeros((song.N, 2))
    for fn, g in ((layer_base, .8), (layer_tension, .9), (layer_drive, 1.0), (layer_climax, .75)):
        st = fn(song, np.random.default_rng(rng.integers(1 << 30)))
        mix += st.render(rev) * g
        del st
    st = layer_boss_extra(song, np.random.default_rng(rng.integers(1 << 30)), c['extra'])
    mix += st.render(rev) * 1.0
    x = finish_stem(mix, -17, peak_db=-2.5, thr_db=-7)
    write_music(OUT / f'music_boss_{carte}_01.ogg', x, items, f'music.boss.{carte} ({c["bpm"]} BPM, {song.n_bars} mesures)')


def render_menu(items, seed):
    c = MENU
    song = Song(c)
    rng = np.random.default_rng(3000 + seed)
    rev = sl.Reverb(np.random.default_rng(27 + seed), rt60=c['rt60'], brightness=.3)
    print('menu bars', song.n_bars, 'dur', song.dur, flush=True)
    st = Stem(song.N)
    for (b0, nb) in song.runs():
        bar = song.bars[b0]
        rpc, ivs = bar['chord']
        pad = sl.pad_chord([M(n) for n in voicing(rpc, ivs, 50)], song.sec(4 * nb), rel=2.6, att=1.8, cut=c['pad_cut'], rng=rng)
        st.add(song, b0, 0, pad, .4, 0, send=.5)
        st.add(song, b0, 0, sl.bass_sine(float(M(bass_midi(rpc, 33))), song.sec(4 * nb) * .96), .45, 0, send=.2)
    for b, bar in enumerate(song.bars):
        rpc, ivs = bar['chord']
        r = 45 + ((rpc - 45) % 12)
        tones = [r, r + ivs[2], r + 12 + ivs[1], r + 12 + ivs[2]]  # fondamentale, quinte, tierce, quinte hautes
        pat = [0, 1, 2, 3, 2, 1, 3, 1]
        for i, k in enumerate(pat):
            x = sl.pluck(float(M(tones[k] + (12 if i == 0 else 0) * 0)), .9, rng, tau=.6, bright=.5)
            st.add(song, b, i * .5 + rng.uniform(-.01, .01), x, .55 if i % 2 == 0 else .38, -.3 + .08 * i, send=.35)
        for (beat, midi, ln) in bar['mel']:
            x = sl.harp(float(M(midi)), song.sec(ln), .65, rng)
            st.add(song, b, beat, x, .7, .15, send=.55)
    music = st.render(rev)
    music *= 10 ** ((-23.5 - ac.rms_db(music)) / 20)
    N = song.N
    nrm = lambda y, db: y * 10 ** ((db - ac.rms_db(y)) / 20)
    fire = nrm(sl.loop_filter(np.column_stack([sl.crackle_fire(N, rng, 16.0, 1.0), sl.crackle_fire(N, rng, 16.0, 1.0)]), lambda t: sl.hp(t, 400, 1)), -37)
    warm = np.column_stack([sl.loop_noise(N, rng, lambda f: np.exp(-(f / 380) ** 2) / np.sqrt(np.maximum(f, 40) / 40)) for _ in (0, 1)])
    warm = nrm(warm * (1 + .2 * sl.smooth_rand_env(N, rng, 9, .5))[:, None], -38)
    rain = np.column_stack([sl.loop_noise(N, rng, lambda f: np.where((f > 800) & (f < 7000), 1.0, .02) * (900 / np.maximum(f, 900)) ** .5) for _ in (0, 1)])
    rain = nrm(rain, -41)
    x = finish_stem(music + fire + warm + rain, -22, peak_db=-3.0, thr_db=-9)
    write_music(OUT / 'music_menu_01.ogg', x, items, f'music.menu (feu de camp, {c["bpm"]} BPM, {song.n_bars} mesures)')


def main():
    global OUT
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=str(OUT))
    ap.add_argument('--seed', type=int, default=0)
    ap.add_argument('--only', default='')
    a = ap.parse_args()
    OUT = Path(a.out)
    OUT.mkdir(parents=True, exist_ok=True)
    items = []
    for carte in CFG:
        if not a.only or a.only == carte:
            render_map(carte, items, a.seed)
    for carte in BOSS:
        if not a.only or a.only == 'boss' or a.only == 'boss_' + carte:
            render_boss(carte, items, a.seed)
    if not a.only or a.only == 'menu':
        render_menu(items, a.seed)
    mf = ROOT / 'art' / 'tools' / 'audio' / 'music_manifest.json'
    old = []
    if a.only and mf.exists():
        old = [o for o in json.load(open(mf, encoding='utf-8')) if o['path'] not in {i['path'] for i in items}]
    json.dump(old + items, open(mf, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)


if __name__ == '__main__':
    main()
