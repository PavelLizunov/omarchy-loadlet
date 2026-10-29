"""Compose a silent walkthrough from actual inert QML renders using FFmpeg."""
from pathlib import Path
import argparse
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
FONT = '/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf'
SCENES = [
    ('map', 'Loadlet 2.17.2', 'Cooling at a glance', 'Temperatures and fan readings\nbeside the computer diagram.\n\nMissing data stays unavailable.'),
    ('history', 'Sensor history', 'Choose a reading', '10 minutes, 1 hour or 6 hours.\n\nRecording is opt-in.\nOpening a chart does not enable it.'),
    ('profiles', 'CPU and cooling', 'Browse, then apply', 'Inspect a preset without\nchanging your hardware.\n\nApply and Edit are separate actions.'),
    ('editor', 'Make it yours', 'Save or save and apply', 'CPU boost, frequency limits\nand supported fan outputs.\n\nSystem controls need optional\nauthenticated helpers.'),
    ('overview', 'See the workload', 'Expand for processes', 'CPU, RAM and per-GPU usage.\n\nSearch and inspect the\nsampled process list.'),
    ('map', 'Loadlet for Omarchy', 'Available on GitHub', 'github.com/PavelLizunov/\nomarchy-loadlet\n\nLinux x86_64 · Omarchy Quattro\nMIT · Based on Activity Monitor\nby Kristoffer Haugland'),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='New external output directory')
    parser.add_argument('--font', default=FONT)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='loadlet-film-') as temporary:
        work = Path(temporary)
        clips = []
        for index, (asset, title, subtitle, body) in enumerate(SCENES):
            for key, value in [('title', title), ('subtitle', subtitle), ('body', body),
                               ('proof', 'Actual QML renders · Demo data · Edited walkthrough, not live capture')]:
                (work / (key + '.txt')).write_text(value)
            filters = [
                '[0:v]scale=1000:760:force_original_aspect_ratio=decrease:flags=lanczos[ui]',
                'color=c=0x0f1314:s=1600x900:r=30:d=4[bg]',
                '[bg][ui]overlay=x=580+(1000-overlay_w)/2:y=60+(760-overlay_h)/2[screen]',
            ]
            draw = []
            for key, size, y, color in [('title', 38, 168, '0xe2e4e4'),
                                         ('subtitle', 25, 236, '0xc7cccc'),
                                         ('body', 22, 312, '0xc7cccc'),
                                         ('proof', 17, 854, '0xa6adad')]:
                draw.append(f'drawtext=fontfile={args.font}:textfile={work / (key + ".txt")}:expansion=none:x=48:y={y}:fontsize={size}:fontcolor={color}:line_spacing=12')
            filters.append('[screen]' + ','.join(draw) + ',format=yuv420p[out]')
            clip = work / f'{index}.mp4'
            subprocess.run(['ffmpeg', '-v', 'error', '-loop', '1', '-framerate', '30',
                            '-i', str(ROOT / 'assets' / (asset + '.png')),
                            '-filter_complex', ';'.join(filters), '-map', '[out]',
                            '-t', '4', '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '17',
                            '-map_metadata', '-1', str(clip)], check=True, timeout=90)
            subprocess.run(['ffmpeg', '-v', 'error', '-i', str(clip), '-frames:v', '1',
                            str(output / f'cover-{index + 1}.png')], check=True, timeout=15)
            clips.append(clip)
        listing = work / 'clips.txt'
        listing.write_text(''.join(f"file '{clip}'\n" for clip in clips))
        subprocess.run(['ffmpeg', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', str(listing),
                        '-c', 'copy', '-map_metadata', '-1', '-movflags', '+faststart',
                        str(output / 'loadlet-2.17.2.mp4')], check=True, timeout=30)
    (output / 'composition.json').write_text(json.dumps({
        'width': 1600, 'height': 900, 'fps': 30, 'durationSeconds': 24,
        'audio': 'none', 'sceneSeconds': 4, 'scenes': SCENES,
        'origin': 'Edited actual-consumer stills, not live telemetry or click-through',
        'validation': 'Encoding completed; no separate decode or interaction test run',
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
