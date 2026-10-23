"""Reusable deterministic procedural audio DSP; sample rate 44100 Hz."""
from pathlib import Path
import subprocess
import numpy as np
from scipy import signal
from scipy.io import wavfile
SR = 44100

def osc(freq, duration=None, kind='sine', sr=SR):
    f = np.asarray(freq)
    if f.ndim == 0: f = np.full(round(duration*sr), float(f))
    phase = np.cumsum(f)/sr
    if kind == 'sine': return np.sin(2*np.pi*phase)
    # Additive synthesis below Nyquist, including for swept frequencies.
    out = np.zeros(len(f)); limit = min(96, int((sr*.48)/max(np.max(f), 1)))
    for k in range(1, limit+1):
        if kind == 'square' and k%2 == 0: continue
        out += np.sin(2*np.pi*k*phase)/k
    return out*(2/np.pi if kind == 'saw' else 4/np.pi)

def noise(n, rng, color='white'):
    x = rng.normal(size=n)
    if color != 'white':
        f = np.fft.rfftfreq(n, 1/SR); w = np.maximum(f, 20)**(-(.5 if color=='pink' else 1))
        x = np.fft.irfft(np.fft.rfft(x)*w, n)
    return x/(np.std(x)+1e-12)

def filt(x, cutoff, kind='lowpass', order=3, sr=SR):
    return signal.sosfilt(signal.butter(order, cutoff, btype=kind, fs=sr, output='sos'), x, axis=0)

def biquad(x, frequency, q=1, kind='peak', sr=SR):
    b,a = signal.iirpeak(frequency, q, fs=sr) if kind=='peak' else signal.iirnotch(frequency,q,fs=sr)
    return signal.lfilter(b,a,x,axis=0)

def adsr(n, attack=.01, decay=.08, sustain=.5, release=.1, sr=SR):
    a,d,r = [min(n,round(v*sr)) for v in (attack,decay,release)]
    total=a+d+r
    if total>n: a,d,r=[int(v*n/total) for v in (a,d,r)]
    return np.concatenate([np.linspace(0,1,a,endpoint=False),np.linspace(1,sustain,d,endpoint=False),np.full(n-a-d-r,sustain),np.linspace(sustain,0,r)])

def exponential(n, tau=.2, sr=SR): return np.exp(-np.arange(n)/(sr*tau))
def fm(carrier, modulator, index, duration, sr=SR):
    t=np.arange(round(duration*sr))/sr
    return np.sin(2*np.pi*carrier*t+index*np.sin(2*np.pi*modulator*t))
def saturate(x, drive=1, mode='tanh'):
    return np.tanh(x*drive)/np.tanh(drive) if mode=='tanh' else x*drive/(1+np.abs(x*drive))
def reverb(x, rng, decay=.3, wet=.2):
    n=round(SR*decay*5); ir=filt(noise(n,rng),5500)*exponential(n,decay)
    ir[:round(.013*SR)]=0; ir/=np.sqrt(np.sum(ir*ir)+1e-12)
    if x.ndim==1: return x+wet*signal.fftconvolve(x,ir)[:len(x)]
    return np.column_stack([reverb(x[:,c],rng,decay,wet) for c in range(x.shape[1])])
def delay(x, seconds=.1, feedback=.25, repeats=3):
    y=x.copy(); k=round(seconds*SR)
    for i in range(1,repeats+1):
        if k*i<len(x): y[k*i:]+=x[:-k*i]*feedback**i
    return y

def pan(x, position=0): return np.column_stack((x*np.sqrt((1-position)/2),x*np.sqrt((1+position)/2)))
def chorus(x, depth=.002, rate=.6, mix=.15):
    t=np.arange(len(x)); shifted=np.interp(t-SR*depth*(1+np.sin(2*np.pi*rate*t/SR)),t,x)
    return np.column_stack((x+mix*shifted,x-mix*shifted))
def stereo(x, width=.4):
    if x.ndim==2:return x
    return chorus(x, mix=width)
def peak_db(x): return float(20*np.log10(np.max(np.abs(x))+1e-12))
def rms_db(x): return float(10*np.log10(np.mean(x*x)+1e-24))
def lufs_approx(x): return rms_db(filt(x,100,'highpass'))-.691
def normalize(x, target_rms=-18, peak=-2.8):
    return x*min(10**((target_rms-rms_db(x))/20),10**((peak-peak_db(x))/20))
def fade(x, ms=3):
    x=x.copy(); k=min(len(x)//2,round(ms*SR/1000)); ramp=np.linspace(0,1,k)
    if x.ndim==2:ramp=ramp[:,None]
    x[:k]*=ramp; x[-k:]*=ramp[::-1]; return x

def write_ogg(path, x, quality=5):
    path=Path(path); path.parent.mkdir(parents=True,exist_ok=True); wav=path.with_suffix('.wav')
    wavfile.write(wav,SR,(np.clip(x,-1,1)*32767).astype(np.int16))
    try: subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(wav),'-c:a','libvorbis','-q:a',str(quality),str(path)],check=True)
    finally: wav.unlink(missing_ok=True)
def decode(path):
    b=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','2','-ar',str(SR),'-'])
    return np.frombuffer(b,dtype='<f4').reshape(-1,2)
