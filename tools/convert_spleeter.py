#!/usr/bin/env python3
"""Day 1 (Path 3): convert Deezer Spleeter *4stems* → Core ML, with parity proof.

Build tooling only — never ships (see tools/README.md, MISSION.md). The bundled
Spleeter model is **MIT (Deezer)**; unlike Demucs it is legal to distribute, so
this package DOES ride in the app bundle as the "Standard" engine.

Export boundary — mirrors convert_htdemucs.py exactly:

    magnitude spectrogram in     (1, T, F, 2)
    → 4 per-stem masked magnitudes out   (1, T, F, 2) each   (= sigmoid_mask · |mix|)

STFT / iSTFT / the soft-mask ratio all stay in Swift (Day 2, Math/SpleeterSpec),
precisely as the emitted manifest's `masking` section prescribes. The model is
only ever fed real tensors.

Nothing here is guessed. Architecture is transcribed from spleeter/model/functions
/unet.py; every scalar is read from the vendored upstream config
(tools/spleeter_configs/4stems.json); weights come from Deezer's official v1.4.0
4stems checkpoint and are restored *by name*, with an assertion that every
checkpoint variable is consumed — which proves the rebuilt graph IS spleeter's.

    source .venv/bin/activate
    python convert_spleeter.py --smoke                       # build + load, no export
    python convert_spleeter.py 2>&1 | tee ../spleeter_export.log
    python convert_spleeter.py --validate                    # parity gate, ≥ 40 dB
"""

import argparse
import json
import sys
import tarfile
import traceback
import urllib.request
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
RESOURCES = TOOLS.parent / "SoundView" / "Resources"
CONFIG_PATH = TOOLS / "spleeter_configs" / "4stems.json"
CHECKPOINT_DIR = TOOLS / "checkpoints" / "4stems"
CHECKPOINT = CHECKPOINT_DIR / "model"

# Deezer's official pretrained weights (release pinned by spleeter's provider).
MODEL_RELEASE = "v1.4.0"
MODEL_URL = (
    f"https://github.com/deezer/spleeter/releases/download/{MODEL_RELEASE}/4stems.tar.gz"
)

WINDOW_COMPENSATION_FACTOR = 2.0 / 3.0  # spleeter EstimatorSpecBuilder, iSTFT gain
EPSILON = 1e-10                         # spleeter EstimatorSpecBuilder, mask floor


def log(msg: str) -> None:
    print(f"[spleeter] {msg}", flush=True)


def load_config() -> dict:
    config = json.loads(CONFIG_PATH.read_text())
    log(f"config {CONFIG_PATH.name}: {config['instrument_list']} "
        f"sr={config['sample_rate']} nfft={config['frame_length']} "
        f"hop={config['frame_step']} T={config['T']} F={config['F']} "
        f"exp={config['separation_exponent']} ext={config['mask_extension']} "
        f"act={config['model']['params']}")
    return config


def ensure_checkpoint() -> None:
    if CHECKPOINT.with_suffix(".index").exists():
        return
    CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
    archive = CHECKPOINT_DIR / "4stems.tar.gz"
    log(f"downloading official checkpoint {MODEL_URL}")
    urllib.request.urlretrieve(MODEL_URL, archive)  # noqa: S310 — pinned GitHub release
    with tarfile.open(archive) as tar:
        tar.extractall(CHECKPOINT_DIR)  # noqa: S202 — trusted first-party archive
    archive.unlink()
    log("checkpoint extracted")


# ---------------------------------------------------------------------------
# U-Net — transcribed verbatim from deezer/spleeter model/functions/unet.py
# (MIT, Deezer). One independent U-Net per instrument: mag in → masked mag out.
# Only cosmetic edits: initializer/activation resolved locally, weights are
# overwritten from the checkpoint so initializer values never matter.
# ---------------------------------------------------------------------------
def apply_unet(input_tensor, output_name, params):
    from functools import partial
    from tensorflow.keras.initializers import HeUniform
    from tensorflow.keras.layers import (
        ELU, BatchNormalization, Concatenate, Conv2D, Conv2DTranspose,
        Dropout, LeakyReLU, Multiply, ReLU,
    )

    def conv_activation():
        name = str(params.get("conv_activation"))
        return ReLU() if name == "ReLU" else ELU() if name == "ELU" else LeakyReLU(0.2)

    def deconv_activation():
        name = str(params.get("deconv_activation"))
        return LeakyReLU(0.2) if name == "LeakyReLU" else ELU() if name == "ELU" else ReLU()

    conv_n_filters = params.get("conv_n_filters", [16, 32, 64, 128, 256, 512])
    kernel_initializer = HeUniform(seed=50)
    conv2d_factory = partial(
        Conv2D, strides=(2, 2), padding="same", kernel_initializer=kernel_initializer
    )
    conv1 = conv2d_factory(conv_n_filters[0], (5, 5))(input_tensor)
    batch1 = BatchNormalization(axis=-1)(conv1)
    rel1 = conv_activation()(batch1)
    conv2 = conv2d_factory(conv_n_filters[1], (5, 5))(rel1)
    batch2 = BatchNormalization(axis=-1)(conv2)
    rel2 = conv_activation()(batch2)
    conv3 = conv2d_factory(conv_n_filters[2], (5, 5))(rel2)
    batch3 = BatchNormalization(axis=-1)(conv3)
    rel3 = conv_activation()(batch3)
    conv4 = conv2d_factory(conv_n_filters[3], (5, 5))(rel3)
    batch4 = BatchNormalization(axis=-1)(conv4)
    rel4 = conv_activation()(batch4)
    conv5 = conv2d_factory(conv_n_filters[4], (5, 5))(rel4)
    batch5 = BatchNormalization(axis=-1)(conv5)
    rel5 = conv_activation()(batch5)
    conv6 = conv2d_factory(conv_n_filters[5], (5, 5))(rel5)
    batch6 = BatchNormalization(axis=-1)(conv6)
    _ = conv_activation()(batch6)

    conv2d_transpose_factory = partial(
        Conv2DTranspose, strides=(2, 2), padding="same",
        kernel_initializer=kernel_initializer,
    )
    up1 = conv2d_transpose_factory(conv_n_filters[4], (5, 5))((conv6))
    up1 = deconv_activation()(up1)
    batch7 = BatchNormalization(axis=-1)(up1)
    drop1 = Dropout(0.5)(batch7)
    merge1 = Concatenate(axis=-1)([conv5, drop1])
    up2 = conv2d_transpose_factory(conv_n_filters[3], (5, 5))((merge1))
    up2 = deconv_activation()(up2)
    batch8 = BatchNormalization(axis=-1)(up2)
    drop2 = Dropout(0.5)(batch8)
    merge2 = Concatenate(axis=-1)([conv4, drop2])
    up3 = conv2d_transpose_factory(conv_n_filters[2], (5, 5))((merge2))
    up3 = deconv_activation()(up3)
    batch9 = BatchNormalization(axis=-1)(up3)
    drop3 = Dropout(0.5)(batch9)
    merge3 = Concatenate(axis=-1)([conv3, drop3])
    up4 = conv2d_transpose_factory(conv_n_filters[1], (5, 5))((merge3))
    up4 = deconv_activation()(up4)
    batch10 = BatchNormalization(axis=-1)(up4)
    merge4 = Concatenate(axis=-1)([conv2, batch10])
    up5 = conv2d_transpose_factory(conv_n_filters[0], (5, 5))((merge4))
    up5 = deconv_activation()(up5)
    batch11 = BatchNormalization(axis=-1)(up5)
    merge5 = Concatenate(axis=-1)([conv1, batch11])
    up6 = conv2d_transpose_factory(1, (5, 5), strides=(2, 2))((merge5))
    up6 = deconv_activation()(up6)
    batch12 = BatchNormalization(axis=-1)(up6)
    up7 = Conv2D(
        2, (4, 4), dilation_rate=(2, 2), activation="sigmoid", padding="same",
        kernel_initializer=kernel_initializer,
    )((batch12))
    return Multiply(name=output_name)([up7, input_tensor])


def build_model(config):
    """4 instrument U-Nets on one shared magnitude input, in config order."""
    import tensorflow as tf

    tf.keras.backend.clear_session()  # reset name counters → match checkpoint names
    frames, freq, channels = config["T"], config["F"], config["n_channels"]
    params = config["model"]["params"]
    inputs = tf.keras.Input(batch_size=1, shape=(frames, freq, channels), name="mag")
    outputs, names = [], []
    for instrument in config["instrument_list"]:
        name = f"{instrument}_spectrogram"
        outputs.append(apply_unet(inputs, output_name=name, params=params))
        names.append(name)
    model = tf.keras.Model(inputs, outputs, name="spleeter_4stems")
    return model, names


def restore_weights(model) -> None:
    """Load Deezer's checkpoint by name. Assert every variable is consumed —
    that equivalence is the proof the rebuilt graph is spleeter's, not a lookalike."""
    import tensorflow as tf

    reader = tf.train.load_checkpoint(str(CHECKPOINT))
    shapes = reader.get_variable_to_shape_map()
    consumed, assigned = set(), 0
    for layer in model.layers:
        for weight in layer.weights:
            var = weight.name.split(":")[0]
            if var not in shapes:
                raise KeyError(f"checkpoint has no variable '{var}'")
            value = reader.get_tensor(var)
            if tuple(value.shape) != tuple(weight.shape):
                raise ValueError(
                    f"shape mismatch {var}: ckpt {value.shape} vs model {tuple(weight.shape)}"
                )
            weight.assign(value)
            consumed.add(var)
            assigned += 1
    # spleeter's unet.py builds `batch6 = BN(conv6)` then feeds the *decoder from
    # conv6*, leaving that one BN per instrument disconnected. Keras prunes those
    # dead layers, so they never reach inference — the checkpoint still carries
    # their (4 vars × N-instrument) weights. Everything else must be consumed.
    leftover = [n for n in shapes if n not in consumed and n != "global_step"]
    dead_layers = {n.rsplit("/", 1)[0] for n in leftover}
    expected_dead = len(model.output_names) if hasattr(model, "output_names") else 4
    if not all(n.startswith("batch_normalization") for n in leftover) \
            or len(dead_layers) != expected_dead:
        raise ValueError(
            f"unexpected unconsumed checkpoint vars ({len(leftover)}): {leftover[:8]}"
        )
    log(f"restored {assigned} tensors; all consumed except spleeter's "
        f"{len(dead_layers)} disconnected batch6 BN layers (expected) ✅")


# ---------------------------------------------------------------------------
# Magnitude spectrogram — spleeter's exact estimator STFT, for the parity gate.
# (prepend one frame of zeros → tf.signal.stft hann-periodic pad_end → |·| →
#  first T frames, first F bins). Matches Math/SpleeterSpec.swift's contract.
# ---------------------------------------------------------------------------
def magnitude_segment(config, waveform):
    import tensorflow as tf

    nfft, hop, channels = config["frame_length"], config["frame_step"], config["n_channels"]
    frames, freq = config["T"], config["F"]
    padded = tf.concat([tf.zeros((nfft, channels), tf.float32), waveform], axis=0)
    stft = tf.signal.stft(
        tf.transpose(padded), nfft, hop,
        window_fn=lambda length, dtype: tf.signal.hann_window(length, True, dtype),
        pad_end=True,
    )
    mag = tf.abs(tf.transpose(stft, perm=[1, 2, 0]))          # (time, bins, ch)
    mag = mag[:frames, :freq, :]
    pad_t = frames - int(mag.shape[0])
    if pad_t > 0:
        mag = tf.pad(mag, [[0, pad_t], [0, 0], [0, 0]])
    return mag.numpy()[None].astype("float32")                # (1, T, F, ch)


def decode_audio(path, config, offset=30.0, seconds=15.0):
    """Decode a musically-active window to 44.1k stereo float32 via ffmpeg CLI —
    no audio-decode Python dependency, no temp file. Real audio (vs synthetic
    tones) drives all four stems with energy, which is what the parity gate needs."""
    import subprocess

    import numpy as np

    sr = config["sample_rate"]
    cmd = [
        "ffmpeg", "-v", "error", "-ss", str(offset), "-t", str(seconds),
        "-i", str(path), "-ac", "2", "-ar", str(sr),
        "-f", "f32le", "-acodec", "pcm_f32le", "pipe:1",
    ]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype("float32")


def synth_waveform(config, seconds=None):
    """Deterministic multi-tone stereo signal → a realistic magnitude spectrum
    (sharp partials over a low floor) without any audio-decode dependency."""
    import numpy as np

    sr = config["sample_rate"]
    seconds = seconds or (config["T"] * config["frame_step"] / sr + 0.2)
    t = np.arange(int(sr * seconds)) / sr
    left = sum(0.3 * np.sin(2 * np.pi * f * t) for f in (110, 247, 440, 1319, 3000))
    right = sum(0.3 * np.sin(2 * np.pi * f * t + 0.5) for f in (146, 330, 660, 1760, 5000))
    stereo = np.stack([left, right], axis=1) + 0.01 * np.sin(2 * np.pi * 50 * t)[:, None]
    return stereo.astype("float32")


# ---------------------------------------------------------------------------


def order_outputs(config, keras_model, keras_names, mlmodel):
    """Map each Core ML output to its instrument by *content* (lowest MSE vs the
    Keras reference on a probe chunk), so the manifest's output order is proven,
    not assumed. Core ML mangles Keras output names, so name-matching won't do."""
    import numpy as np

    probe = magnitude_segment(config, synth_waveform(config))
    reference = keras_model.predict(probe, verbose=0)
    if not isinstance(reference, list):
        reference = [reference]
    ref_by_instrument = {
        inst: np.asarray(r).reshape(-1)
        for inst, r in zip([n.replace("_spectrogram", "") for n in keras_names], reference)
    }
    prediction = mlmodel.predict({"mag": probe})
    coreml_flat = {k: np.asarray(v, np.float32).reshape(-1) for k, v in prediction.items()}

    ordered, used = [], set()
    for instrument in config["instrument_list"]:
        ref = ref_by_instrument[instrument]
        best, best_mse = None, float("inf")
        for name, vec in coreml_flat.items():
            if name in used or vec.size != ref.size:
                continue
            mse = float(np.mean((vec - ref) ** 2))
            if mse < best_mse:
                best, best_mse = name, mse
        if best is None:
            raise ValueError(f"no Core ML output matches instrument '{instrument}'")
        # A correct match is near-exact (fp16); a wrong stem is orders larger.
        log(f"output map: {instrument} ← '{best}' (mse {best_mse:.2e})")
        ordered.append(best)
        used.add(best)
    if len(set(ordered)) != len(config["instrument_list"]):
        raise ValueError(f"output mapping is not a bijection: {ordered}")
    return ordered


def write_manifest(config, mlmodel, ordered_outputs) -> Path:
    description = mlmodel.get_spec().description
    nfft, freq = config["frame_length"], config["F"]
    full_bins = nfft // 2 + 1
    manifest = {
        "model": "spleeter_4stems",
        "license": "MIT (Deezer) — bundled as the Standard engine",
        "provenance": {
            "config": f"tools/spleeter_configs/{CONFIG_PATH.name} (deezer/spleeter, MIT)",
            "weights": f"deezer/spleeter release {MODEL_RELEASE} 4stems.tar.gz",
            "architecture": "model/functions/unet.py unet.unet (per-instrument U-Net)",
        },
        "sources": config["instrument_list"],
        "sample_rate": config["sample_rate"],
        "n_fft": nfft,
        "hop": config["frame_step"],
        "frames": config["T"],
        "freq_bins_model": freq,
        "freq_bins_full": full_bins,
        "n_channels": config["n_channels"],
        "spec_exponent": 1,
        "stft": {
            "window": "hann_periodic",
            "center": False,
            "pad_end": True,
            "prepad_samples": nfft,
            "window_compensation_factor": WINDOW_COMPENSATION_FACTOR,
            "crop_leading_samples": nfft,
        },
        "inputs": [f.name for f in description.input],
        "input_shape": [1, config["T"], freq, config["n_channels"]],
        "outputs": ordered_outputs,  # aligned to output_order below (proven by content)
        "output_order": config["instrument_list"],
        "output_shape": [1, config["T"], freq, config["n_channels"]],
        "masking": {
            "type": "ratio_softmask",
            "separation_exponent": config["separation_exponent"],
            "epsilon": EPSILON,
            "n_sources": len(config["instrument_list"]),
            "note": "model output_i = sigmoid_mask_i · |mix_mag| (already multiplied)",
            "mask_i": "(output_i**p + epsilon/N) / (sum_j output_j**p + epsilon)",
            "mask_extension": config["mask_extension"],
            "extend_from_bins": freq,
            "extend_to_bins": full_bins,
            "apply": "masked_stft_i = complex(extend(mask_i)) * mix_stft; extended bins are 0",
        },
    }
    path = RESOURCES / "spleeter_manifest.json"
    path.write_text(json.dumps(manifest, indent=2))
    log(f"saved {path}")
    return path


def export(config) -> int:
    import coremltools as ct

    ensure_checkpoint()
    model, names = build_model(config)
    restore_weights(model)
    frames, freq, channels = config["T"], config["F"], config["n_channels"]

    log(f"converting to ML Program (fp16, iOS17), input mag(1,{frames},{freq},{channels})…")
    mlmodel = ct.convert(
        model,
        source="tensorflow",
        inputs=[ct.TensorType(name="mag", shape=(1, frames, freq, channels))],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16,
    )
    RESOURCES.mkdir(parents=True, exist_ok=True)
    package = RESOURCES / "spleeter_4stems.mlpackage"
    mlmodel.save(str(package))
    log(f"saved {package}")
    ordered = order_outputs(config, model, names, mlmodel)
    write_manifest(config, mlmodel, ordered)
    log(f"EXPORT OK — outputs (vocals,drums,bass,other) → {ordered}. "
        f"Next: --validate, then coremlcompiler compile.")
    return 0


def validate(config, audio_path=None) -> int:
    """Parity: Keras (= spleeter, proven by restore) vs Core ML on one mag chunk.
    Gate: worst-tensor SNR ≥ 40 dB (fp16 tolerance)."""
    import coremltools as ct
    import numpy as np

    ensure_checkpoint()
    model, names = build_model(config)
    restore_weights(model)

    if audio_path and Path(audio_path).exists():
        try:
            waveform = decode_audio(audio_path, config)
            source = f"{audio_path} (30s+, real audio)"
        except Exception as exc:  # noqa: BLE001
            log(f"cannot decode {audio_path} ({exc}); using synthesized chunk")
            waveform = synth_waveform(config)
            source = "synthesized multi-tone chunk"
    else:
        waveform = synth_waveform(config)
        source = "synthesized multi-tone chunk (tonal → 3 stems near-silent; "
        "prefer --validate <audio> for a real parity number)"
    log(f"parity input: {source}")

    mag = magnitude_segment(config, waveform)
    reference = model.predict(mag, verbose=0)
    if not isinstance(reference, list):
        reference = [reference]
    ref_by_instrument = {
        n.replace("_spectrogram", ""): np.asarray(r).reshape(-1)
        for n, r in zip(names, reference)
    }

    package = RESOURCES / "spleeter_4stems.mlpackage"
    mlmodel = ct.models.MLModel(str(package))
    prediction = mlmodel.predict({"mag": mag})
    coreml_flat = {k: np.asarray(v, np.float32).reshape(-1) for k, v in prediction.items()}

    # Pair each Core ML output with its instrument by content (all 4 share a
    # size, so name/size matching would compare the wrong stems).
    worst = float("inf")
    for instrument in config["instrument_list"]:
        ref = ref_by_instrument[instrument]
        name, out = min(
            ((k, v) for k, v in coreml_flat.items() if v.size == ref.size),
            key=lambda kv: float(np.mean((kv[1] - ref) ** 2)),
        )
        noise = float(np.sum((out - ref) ** 2)) + 1e-12
        snr = 10 * np.log10(float(np.sum(ref**2)) / noise)
        worst = min(worst, snr)
        log(f"{instrument} ← '{name}': SNR {snr:.1f} dB")

    passed = worst >= 40
    log(f"PARITY {'PASS ✅' if passed else 'FAIL ❌'} (worst {worst:.1f} dB, gate 40 dB)")
    return 0 if passed else 1


def smoke(config) -> int:
    import numpy as np

    ensure_checkpoint()
    model, names = build_model(config)
    restore_weights(model)
    total = int(sum(np.prod(w.shape) for layer in model.layers for w in layer.weights))
    log(f"SMOKE OK — model built, {total:,} params, outputs {names}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--validate", nargs="?", const="", metavar="AUDIO")
    args = parser.parse_args()
    try:
        config = load_config()
        if args.smoke:
            return smoke(config)
        if args.validate is not None:
            return validate(config, args.validate or None)
        return export(config)
    except Exception:  # noqa: BLE001 — full trace IS the deliverable on failure
        traceback.print_exc()
        log("FAILED — tee this log into the repo; iterate from the trace.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
