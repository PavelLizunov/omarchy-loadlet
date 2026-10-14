"""Render the actual-assets documentation video through Motion Studio capture."""
from pathlib import Path
import json
import os
import shutil
import signal
import subprocess
import sys
import time


def run(argv, root, log, timeout):
    started = time.monotonic()
    with log.open('w') as stream:
        process = subprocess.Popen(argv, cwd=root, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except BaseException:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            raise
        finally:
            # Close only this command's owned descendants, including failed browser startup.
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
    assert code == 0, 'Render stage failed; inspect ' + str(log)
    return {'argv': argv, 'pid': process.pid, 'exit': code, 'seconds': time.monotonic() - started}


def main():
    assert len(sys.argv) == 3, 'Usage: render.py CAPTURE_MJS NEW_EXTERNAL_OUTPUT_DIRECTORY'
    source = Path(__file__).resolve().parent
    capture = Path(sys.argv[1]).resolve(strict=True)
    destination = Path(sys.argv[2]).resolve()
    assert not destination.is_relative_to(source) and not destination.exists()
    destination.mkdir(parents=True)
    project = destination / 'project'
    shutil.copytree(source, project, ignore=shutil.ignore_patterns('.cache', '*.mp4', '__pycache__', 'covers'))
    records = []
    common = ['node', str(capture)]
    def stage(args, log, bound):
        records.append(run(common + args + ['--root', str(project)], project, destination / log, bound))
    stage(['doctor'], 'doctor.log', 10)
    stage(['verify', '--n', '30'], 'determinism.log', 45)
    covers = destination / 'covers'
    stage(['still', '1', '5', '8.5', '11.5', '14.5', '--out', str(covers)], 'covers.log', 30)
    stage(['render', '--from', '0', '--to', '16', '--sub', '1', '--crf', '0', '--out', str(destination / 'pristine.mp4')], 'render.log', 120)
    for suffix, crf, width in [('', '14', None), ('-web', '19', '960')]:
        argv = ['ffmpeg', '-v', 'error', '-i', str(destination / 'pristine.mp4')]
        if width:
            argv += ['-vf', 'scale=960:540:flags=lanczos']
        argv += ['-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', crf,
                 '-pix_fmt', 'yuv420p', '-map_metadata', '-1', '-movflags', '+faststart',
                 str(destination / ('loadlet' + suffix + '.mp4'))]
        records.append(run(argv, project, destination / ('encode' + suffix + '.log'), 40))
        records.append(run(['ffmpeg', '-v', 'error', '-i', argv[-1], '-f', 'null', '-'],
                           project, destination / ('decode' + suffix + '.log'), 30))
        probe = subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format',
                                         '-of', 'json', argv[-1]], timeout=10)
        (destination / ('probe' + suffix + '.json')).write_bytes(probe)
        video = json.loads(probe)
        assert len(video['streams']) == 1 and video['streams'][0]['codec_name'] == 'h264'
        assert video['streams'][0]['nb_frames'] == '480' and video['streams'][0]['r_frame_rate'] == '30/1'
        assert abs(float(video['format']['duration']) - 16) < .01
    (destination / 'processes.json').write_text(json.dumps(records, indent=2) + '\n')
    print('PASS Motion Studio render: silent16s/30FPS/480frames, master+messenger, decode+determinism; ' + str(destination))


if __name__ == '__main__':
    main()
