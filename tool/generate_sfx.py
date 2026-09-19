import os
import math
import struct
import wave
import random

SAMPLE_RATE = 44100

def write_wav(filename, samples):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'wb') as wav:
        wav.setnchannels(1)  # Mono
        wav.setsampwidth(2)  # 16-bit
        wav.setframerate(SAMPLE_RATE)
        
        raw_data = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            val = int(clamped * 32767)
            raw_data.extend(struct.pack('<h', val))
        wav.writeframes(raw_data)
    print(f"Generated {filename} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f}s)")

def generate_whistle():
    # Double blast referee whistle
    duration_blast = 0.22
    silence = 0.06
    duration_blast2 = 0.32
    
    samples = []
    
    def render_blast(dur, accent=1.0):
        n = int(SAMPLE_RATE * dur)
        out = []
        for i in range(n):
            t = i / SAMPLE_RATE
            # Tremolo pea modulation (25 Hz)
            tremolo = 0.75 + 0.25 * math.sin(2 * math.pi * 28 * t)
            # Frequency modulation
            fm = 15 * math.sin(2 * math.pi * 28 * t)
            f1 = 2650 + fm
            f2 = 2920 + fm
            
            # Envelope
            attack = min(1.0, i / (SAMPLE_RATE * 0.015))
            decay = min(1.0, (n - i) / (SAMPLE_RATE * 0.025))
            env = attack * decay * accent
            
            # Whistle air turbulence (subtle noise)
            noise = (random.random() * 2 - 1) * 0.06
            
            tone = 0.5 * math.sin(2 * math.pi * f1 * t) + 0.4 * math.sin(2 * math.pi * f2 * t) + noise
            out.append(tone * tremolo * env * 0.85)
        return out
    
    samples.extend(render_blast(duration_blast, 0.9))
    samples.extend([0.0] * int(SAMPLE_RATE * silence))
    samples.extend(render_blast(duration_blast2, 1.0))
    return samples

def generate_goal():
    # Stadium boom kick + celebration chord
    dur = 1.3
    n = int(SAMPLE_RATE * dur)
    samples = []
    
    freqs = [261.63, 329.63, 392.00, 523.25, 659.25] # C Major chord
    
    for i in range(n):
        t = i / SAMPLE_RATE
        
        # Bass thud sweep (120 Hz down to 45 Hz)
        if t < 0.25:
            f_bass = 120 * math.exp(-t * 8)
            bass_env = math.exp(-t * 14)
            bass = math.sin(2 * math.pi * f_bass * t) * bass_env * 0.8
        else:
            bass = 0.0
            
        # Celebration chime/horns
        chord = 0.0
        for f in freqs:
            chord += math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2 * t)
        chord /= len(freqs)
        
        # Swell and decay envelope
        chord_env = min(1.0, t / 0.04) * math.exp(-t * 2.5)
        
        # Crowd roar / noise swell
        noise = (random.random() * 2 - 1) * 0.12 * math.exp(-t * 2.0)
        
        samples.append(bass + chord * chord_env * 0.7 + noise)
    return samples

def generate_correct():
    # Ascending sparkling chime: C5 -> E5 -> G5 -> C6
    notes = [
        (523.25, 0.08),  # C5
        (659.25, 0.08),  # E5
        (783.99, 0.08),  # G5
        (1046.50, 0.22), # C6
    ]
    
    total_dur = sum(d for _, d in notes)
    n_total = int(SAMPLE_RATE * total_dur)
    samples = [0.0] * n_total
    
    curr_sample = 0
    for freq, dur in notes:
        n_note = int(SAMPLE_RATE * dur)
        # Ring out slightly longer
        ring_n = int(SAMPLE_RATE * (dur + 0.15))
        
        for i in range(ring_n):
            idx = curr_sample + i
            if idx >= n_total:
                break
            t = i / SAMPLE_RATE
            env = min(1.0, i / (SAMPLE_RATE * 0.005)) * math.exp(-t * 8)
            # Pure sine + subtle bell harmonic (3x)
            val = (math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(2 * math.pi * freq * 3 * t)) * env * 0.55
            samples[idx] += val
        curr_sample += n_note
        
    return samples

def generate_wrong():
    # Low dissonant buzz + soft wooden thud
    dur = 0.35
    n = int(SAMPLE_RATE * dur)
    samples = []
    
    f1 = 185.0 # F#3
    f2 = 196.0 # G3 (minor 2nd clash)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        env = min(1.0, i / (SAMPLE_RATE * 0.01)) * math.exp(-t * 9)
        # Low saw-like distortion
        buzz = (math.sin(2 * math.pi * f1 * t) + 
                math.sin(2 * math.pi * f2 * t) + 
                0.4 * math.sin(2 * math.pi * (f1 * 2) * t)) * 0.5
        
        # Thud impact
        thud = math.sin(2 * math.pi * (80 * math.exp(-t * 15)) * t) * math.exp(-t * 20) * 0.6
        
        samples.append((buzz * 0.6 + thud) * env * 0.75)
    return samples

def generate_click():
    # Crisp tactile UI click (25ms)
    dur = 0.035
    n = int(SAMPLE_RATE * dur)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 140) # Rapid exponential decay
        val = math.sin(2 * math.pi * 1400 * t) + 0.4 * math.sin(2 * math.pi * 700 * t)
        samples.append(val * env * 0.6)
    return samples

def generate_kick():
    # Football boot impact thump (0.16s)
    dur = 0.16
    n = int(SAMPLE_RATE * dur)
    samples = []
    
    for i in range(n):
        t = i / SAMPLE_RATE
        f = 95 * math.exp(-t * 22) + 38
        env = math.exp(-t * 18)
        # Leather impact click on attack
        click = (random.random() * 2 - 1) * 0.4 * math.exp(-t * 90)
        thump = math.sin(2 * math.pi * f * t) * env * 0.85
        samples.append((thump + click) * 0.9)
    return samples

if __name__ == '__main__':
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
    os.makedirs(out_dir, exist_ok=True)
    
    write_wav(os.path.join(out_dir, 'whistle.wav'), generate_whistle())
    write_wav(os.path.join(out_dir, 'goal.wav'), generate_goal())
    write_wav(os.path.join(out_dir, 'correct.wav'), generate_correct())
    write_wav(os.path.join(out_dir, 'wrong.wav'), generate_wrong())
    write_wav(os.path.join(out_dir, 'click.wav'), generate_click())
    write_wav(os.path.join(out_dir, 'kick.wav'), generate_kick())
    print("All Touchline SFX assets generated successfully!")
