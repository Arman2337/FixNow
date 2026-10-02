/**
 * Audio fixtures with real container signatures.
 *
 * SEC-014. `assertAllowedAudio` now sniffs the container and requires it to
 * agree with the declared mime type, the same rule the image path already
 * enforced. That makes three pre-existing fixtures invalid: they were built as
 * `Buffer.from(someTranscribedText)` labelled `audio/mpeg`, which is not an
 * MPEG file — it is a text file with a lie on it.
 *
 * These were passing because mime was trusted. They are the exact case the
 * control exists for, so the fixtures are corrected rather than the control
 * weakened: a test whose audio payload is not audio proves nothing about the
 * transcription path, and it would have hidden a disguised payload reaching a
 * paid provider.
 *
 * Each builder returns a payload whose leading bytes are a genuine signature for
 * the container, followed by filler. That is enough for identification, which is
 * what the gate checks — full decoding is the provider's job and Whisper's own.
 */
import type { MediaPayload } from './ai-media-policy';

/** MPEG-1 Layer III frame sync plus a plausible header byte. */
export function mpegAudioBytes(filler = 64): Buffer {
  const header = Buffer.from([0xff, 0xfb, 0x90, 0x64]);
  return Buffer.concat([header, Buffer.alloc(filler, 0x00)]);
}

/**
 * An MPEG container whose payload carries `transcript` as UTF-8 text.
 *
 * `DeterministicAiProvider` synthesises a transcription by decoding the audio
 * bytes as UTF-8, which is what lets a test drive an exact transcript without a
 * model or a network call. SEC-014 made those bytes subject to a real container
 * sniff, so a bare transcript is no longer accepted — which is correct, since it
 * is a text file claiming to be audio.
 *
 * Prepending a genuine frame header satisfies both requirements at once: the
 * payload is identifiable as MPEG, and the deterministic provider still reads
 * the transcript. The text is unreachable to a real decoder as audio content,
 * which is exactly why this belongs in a test helper and never in production
 * code — real callers upload a recording, not a string.
 */
export function mpegAudioWithTranscript(transcript: string): Buffer {
  return Buffer.concat([mpegAudioBytes(0), Buffer.from(transcript, 'utf8')]);
}

/** ID3v2 tag immediately followed by an MPEG frame sync. */
export function id3TaggedMpegBytes(filler = 64): Buffer {
  const id3 = Buffer.concat([
    Buffer.from('ID3', 'ascii'),
    Buffer.from([0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a]),
    Buffer.alloc(10, 0x00),
  ]);
  return Buffer.concat([id3, mpegAudioBytes(filler)]);
}

/** ISO base media: `....ftypM4A `, which is what `.m4a` actually is. */
export function m4aBytes(filler = 64): Buffer {
  const box = Buffer.concat([
    Buffer.from([0x00, 0x00, 0x00, 0x20]),
    Buffer.from('ftypM4A ', 'ascii'),
    Buffer.from([0x00, 0x00, 0x00, 0x00]),
    Buffer.from('M4A ', 'ascii'),
    Buffer.from('mp42isom', 'ascii'),
  ]);
  return Buffer.concat([box, Buffer.alloc(filler, 0x00)]);
}

/** RIFF/WAVE header followed by a `fmt ` chunk. */
export function wavBytes(filler = 64): Buffer {
  const body = Buffer.concat([
    Buffer.from('WAVE', 'ascii'),
    Buffer.from('fmt ', 'ascii'),
    Buffer.alloc(16, 0x00),
    Buffer.from('data', 'ascii'),
    Buffer.alloc(filler, 0x00),
  ]);
  const size = Buffer.alloc(4);
  size.writeUInt32LE(body.length, 0);
  return Buffer.concat([Buffer.from('RIFF', 'ascii'), size, body]);
}

/** Ogg page with a Vorbis identification header. */
export function oggBytes(filler = 64): Buffer {
  const page = Buffer.concat([
    Buffer.from('OggS', 'ascii'),
    Buffer.from([0x00, 0x02]),
    Buffer.alloc(8, 0x00),
    Buffer.from([0x01, 0x1e]),
    Buffer.from('vorbis', 'ascii'),
    Buffer.alloc(filler, 0x00),
  ]);
  return page;
}

/** `fLaC` stream-init header. */
export function flacBytes(filler = 64): Buffer {
  return Buffer.concat([
    Buffer.from('fLaC', 'ascii'),
    Buffer.from([0x00, 0x00, 0x00, 0x22]),
    Buffer.alloc(filler, 0x00),
  ]);
}

/** EBML header with the WebM doctype. */
export function webmAudioBytes(filler = 64): Buffer {
  return Buffer.concat([
    Buffer.from([0x1a, 0x45, 0xdf, 0xa3]),
    Buffer.from([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1f]),
    Buffer.from('webm', 'ascii'),
    Buffer.alloc(filler, 0x00),
  ]);
}

/** Raw ADTS AAC frame: sync word with layer bits cleared. */
export function adtsAacBytes(filler = 64): Buffer {
  return Buffer.concat([
    Buffer.from([0xff, 0xf1, 0x50, 0x80]),
    Buffer.alloc(filler, 0x00),
  ]);
}

/**
 * A payload that is text wearing an `audio/mpeg` label — the disguise the gate
 * now rejects, and the shape every broken fixture in this repository had.
 */
export function disguisedTextAsAudio(text: string): MediaPayload {
  return { bytes: Buffer.from(text, 'utf8'), mimeType: 'audio/mpeg' };
}

export const AUDIO_FIXTURES = {
  mpeg: (): MediaPayload => ({
    bytes: mpegAudioBytes(),
    mimeType: 'audio/mpeg',
  }),
  id3Mpeg: (): MediaPayload => ({
    bytes: id3TaggedMpegBytes(),
    mimeType: 'audio/mpeg',
  }),
  m4a: (): MediaPayload => ({ bytes: m4aBytes(), mimeType: 'audio/mp4' }),
  wav: (): MediaPayload => ({ bytes: wavBytes(), mimeType: 'audio/wav' }),
  ogg: (): MediaPayload => ({ bytes: oggBytes(), mimeType: 'audio/ogg' }),
  flac: (): MediaPayload => ({ bytes: flacBytes(), mimeType: 'audio/flac' }),
  webm: (): MediaPayload => ({
    bytes: webmAudioBytes(),
    mimeType: 'audio/webm',
  }),
  aac: (): MediaPayload => ({
    bytes: adtsAacBytes(),
    mimeType: 'audio/aac',
  }),
} as const;
