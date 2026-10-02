/**
 * Bounded validation for media that crosses the AI provider boundary (FN-058
 * audio, FN-059 images). Enforces a mime allow-list, a byte ceiling, and
 * non-emptiness; for images it additionally sniffs magic bytes and requires
 * them to match the declared type, so a mislabelled or disguised payload is
 * rejected before any provider call. Rejections are `INPUT_REJECTED`.
 *
 * Sanitisation: `stripImageMetadata` removes privacy-bearing metadata
 * (EXIF/XMP/IPTC — GPS, device identifiers, timestamps) from a validated image
 * before it crosses the provider boundary. Malware scanning remains a deferred,
 * vendor-gated hook (ADR-0014 release gate) — see
 * `docs/ai/problem-classification.md`.
 */

import { AiError } from '../contracts/ai-errors';

export interface MediaPayload {
  readonly bytes: Buffer;
  readonly mimeType: string;
}

export const ALLOWED_IMAGE_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
] as const;

export const ALLOWED_AUDIO_MIME_TYPES = [
  'audio/mpeg',
  'audio/mp3',
  'audio/mp4',
  'audio/m4a',
  'audio/x-m4a',
  'audio/wav',
  'audio/x-wav',
  'audio/webm',
  'audio/ogg',
  'audio/flac',
  'audio/aac',
] as const;

export function assertAllowedImage(
  media: MediaPayload,
  maxBytes: number,
): void {
  const declared = assertAllowedMedia(
    media,
    ALLOWED_IMAGE_MIME_TYPES,
    maxBytes,
  );
  const sniffed = sniffImageMime(media.bytes);
  // Magic bytes must be recognised AND agree with the declared type.
  if (sniffed === null || sniffed !== declared) {
    throw new AiError('INPUT_REJECTED');
  }
}

/**
 * SEC-014. Audio is now sniffed, not just trusted.
 *
 * The previous comment was honest that audio containers are "too varied to sniff
 * reliably" — which is true of *decoding* them and irrelevant to identifying
 * them. Every container in the allow-list starts with a fixed byte signature,
 * and checking those is not the same task as parsing an MP3 frame. Declaring
 * `audio/mpeg` while sending a ZIP, an ELF binary or a PDF is exactly the
 * disguise the image path already rejects, and it was the one gap left in a
 * control that otherwise exists: the client controls both the bytes and the
 * declared type, so mime alone proves nothing.
 *
 * Sniffing is deliberately a prefix check rather than a full parse. A
 * conservative matcher that identifies the common case and refuses the rest is
 * the right trade here — an unrecognised container is rejected rather than
 * forwarded, so adding a format later is a one-line allow-list change and never a
 * security change.
 */
export function assertAllowedAudio(
  media: MediaPayload,
  maxBytes: number,
): void {
  const declared = assertAllowedMedia(
    media,
    ALLOWED_AUDIO_MIME_TYPES,
    maxBytes,
  );
  const sniffed = sniffAudioContainer(media.bytes);
  // `null` means the container was not recognised, which is a rejection, not a
  // pass: forwarding an unidentifiable payload to a paid provider is how a
  // binary ends up being billed as a voice transcription.
  if (sniffed === null || !AUDIBLE_CONTAINERS[declared]?.includes(sniffed)) {
    throw new AiError('INPUT_REJECTED');
  }
}

/**
 * Container signatures for the audio types in the allow-list.
 *
 * Keyed by the *declared* mime so a payload claiming to be one format while
 * carrying another is rejected, the same way the image path requires the
 * sniffed type to equal the declared one.
 */
const AUDIBLE_CONTAINERS: Readonly<Record<string, readonly AudioContainer[]>> =
  {
    'audio/mpeg': ['mp3', 'mp3-id3'],
    'audio/mp3': ['mp3', 'mp3-id3'],
    'audio/mp4': ['mp4'],
    'audio/m4a': ['mp4'],
    'audio/x-m4a': ['mp4'],
    'audio/wav': ['wav', 'riff-wave'],
    'audio/x-wav': ['wav', 'riff-wave'],
    'audio/webm': ['webm'],
    'audio/ogg': ['ogg'],
    'audio/flac': ['flac'],
    'audio/aac': ['adts-aac', 'mp4'],
  };

export type AudioContainer =
  | 'mp3'
  | 'mp3-id3'
  | 'mp4'
  | 'wav'
  | 'riff-wave'
  | 'webm'
  | 'ogg'
  | 'flac'
  | 'adts-aac';

/**
 * How many leading bytes identify each container.
 *
 * Exported so the deterministic provider can skip the signature it recognises
 * without re-deriving it, keeping the two in step.
 */
export const AUDIO_CONTAINER_HEADER_BYTES: Readonly<
  Record<AudioContainer, number>
> = {
  // A 4-byte MPEG frame header; the ID3 variant is a 10-byte tag.
  mp3: 4,
  'mp3-id3': 10,
  // `....ftyp` + the brand, i.e. up to and including `ftypM4A `.
  mp4: 12,
  // `RIFF` + size + `WAVE` is a complete 12-byte container header.
  wav: 12,
  // Recognised only as "some RIFF container"; the size field is not fixed.
  'riff-wave': 12,
  // EBML header through the doctype. Short enough to cover `webm`.
  webm: 14,
  // `OggS` page header through the codec identifier.
  ogg: 28,
  // `fLaC` plus the metadata-block header.
  flac: 8,
  // A two-byte ADTS sync word is enough to identify raw AAC frames.
  'adts-aac': 2,
};

/**
 * Identify the audio container from its leading bytes.
 *
 * Returns `null` for anything unrecognised, which callers treat as a rejection.
 */
export function sniffAudioContainer(bytes: Buffer): AudioContainer | null {
  if (!Buffer.isBuffer(bytes) || bytes.length < 4) return null;

  // ISO base media (MP4 / M4A): `....ftyp`
  if (bytes.length >= 12 && bytes.toString('ascii', 4, 8) === 'ftyp') {
    return 'mp4';
  }
  // Matroska / WebM. The DocType is checked rather than just the EBML magic,
  // because MKV video is not audio and would otherwise satisfy the check.
  if (
    bytes.length >= 4 &&
    bytes[0] === 0x1a &&
    bytes[1] === 0x45 &&
    bytes[2] === 0xdf &&
    bytes[3] === 0xa3
  ) {
    const docType = readAscii(bytes, 4, Math.min(bytes.length, 40));
    if (docType.includes('webm')) return 'webm';
    return null;
  }
  // OggS, then the codec within the first page.
  if (bytes.length >= 4 && bytes.toString('ascii', 0, 4) === 'OggS') {
    const head = readAscii(bytes, 0, Math.min(bytes.length, 64));
    if (head.includes('OpusHead') || head.includes('vorbis')) return 'ogg';
    return null;
  }
  // fLaC
  if (bytes.length >= 4 && bytes.toString('ascii', 0, 4) === 'fLaC') {
    return 'flac';
  }
  // RIFF container: distinguish WAVE from anything else (AVI, WEBP, ...).
  if (
    bytes.length >= 12 &&
    bytes.toString('ascii', 0, 4) === 'RIFF' &&
    bytes.toString('ascii', 8, 12) === 'WAVE'
  ) {
    return 'wav';
  }
  if (bytes.length >= 12 && bytes.toString('ascii', 0, 4) === 'RIFF') {
    return 'riff-wave';
  }
  // ID3 tag precedes MPEG audio frames.
  if (bytes.toString('ascii', 0, 3) === 'ID3') return 'mp3-id3';
  // ADTS raw AAC frames: 12 sync bits, layer bits must be zero.
  if (
    bytes.length >= 2 &&
    (bytes[0] & 0xff) === 0xff &&
    (bytes[1] & 0xf0) === 0xf0
  ) {
    const layer = (bytes[1] >> 1) & 0x03;
    if (layer === 0) return 'adts-aac';
  }
  // MPEG audio frame sync: 11 set bits, then a non-reserved layer and bitrate.
  if (
    bytes.length >= 2 &&
    (bytes[0] & 0xff) === 0xff &&
    (bytes[1] & 0xe0) === 0xe0
  ) {
    const layer = (bytes[1] >> 1) & 0x03;
    const bitrate = (bytes[2] >> 4) & 0x0f;
    const sampleRate = (bytes[2] >> 2) & 0x03;
    if (layer !== 0 && bitrate !== 0x0f && bitrate !== 0 && sampleRate !== 3) {
      return 'mp3';
    }
  }
  return null;
}

function readAscii(bytes: Buffer, from: number, to: number): string {
  return bytes.subarray(from, to).toString('latin1');
}

/**
 * Remove privacy-bearing metadata from a validated image before it crosses the
 * AI provider boundary (ADR-0014). Strips EXIF/XMP/IPTC (GPS coordinates,
 * device identifiers, capture timestamps, authored captions) while preserving
 * pixels and colour-critical segments (ICC / Adobe profiles). Call ONLY on
 * bytes already accepted by `assertAllowedImage`.
 *
 * Best-effort by design: `assertAllowedImage` is the gatekeeper (type + size +
 * magic bytes); this stripper cleans what it can parse and forwards a payload
 * it cannot parse unchanged rather than rejecting it — a real vision provider
 * rejects genuinely undecodable images on its own.
 *
 * ponytail: hand-rolled marker/chunk walk, no image dependency. Covers the
 * standardised metadata containers (JPEG APPn/COM, PNG text/eXIf/tIME, WEBP
 * EXIF/XMP). Exotic private markers (e.g. maker-note blobs in APP4) are out of
 * scope; add a re-encode pass (sharp) if that ever becomes a requirement.
 */
export function stripImageMetadata(media: MediaPayload): MediaPayload {
  try {
    switch (sniffImageMime(media.bytes)) {
      case 'image/jpeg':
        return { bytes: stripJpeg(media.bytes), mimeType: media.mimeType };
      case 'image/png':
        return { bytes: stripPng(media.bytes), mimeType: media.mimeType };
      case 'image/webp':
        return { bytes: stripWebp(media.bytes), mimeType: media.mimeType };
      default:
        return media;
    }
  } catch {
    // Unparseable payload (already past the type/size gate): forward unchanged.
    return media;
  }
}

// JPEG: drop metadata APP segments (APP1 EXIF/XMP, APP13 IPTC, any other APPn)
// and COM comments; keep APP0/JFIF, APP2/ICC and APP14/Adobe so colour renders
// unchanged. Everything from the first scan (SOS) onward — the entropy-coded
// pixel data — is copied verbatim.
function stripJpeg(buf: Buffer): Buffer {
  const out: Buffer[] = [buf.subarray(0, 2)]; // SOI (FF D8)
  let i = 2;
  while (i + 1 < buf.length) {
    if (buf[i] !== 0xff) throw new AiError('INPUT_REJECTED');
    const marker = buf[i + 1];
    if (marker === 0xff) {
      i += 1; // fill byte before the real marker
      continue;
    }
    if (marker === 0xda || marker === 0xd9) {
      out.push(buf.subarray(i)); // SOS/EOI: copy the remainder untouched
      return Buffer.concat(out);
    }
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      out.push(buf.subarray(i, i + 2)); // standalone marker, no length
      i += 2;
      continue;
    }
    const segLen = buf.readUInt16BE(i + 2); // includes the 2 length bytes
    const end = i + 2 + segLen;
    if (segLen < 2 || end > buf.length) throw new AiError('INPUT_REJECTED');
    const isAppn = marker >= 0xe0 && marker <= 0xef;
    const keep =
      marker === 0xe0 || // APP0  JFIF
      marker === 0xe2 || // APP2  ICC colour profile
      marker === 0xee || // APP14 Adobe colour transform
      (!isAppn && marker !== 0xfe); // any non-APP, non-COM segment
    if (keep) out.push(buf.subarray(i, end));
    i = end;
  }
  return Buffer.concat(out);
}

// PNG: drop the textual/metadata chunks; every other chunk (and its valid CRC)
// is copied verbatim.
const PNG_DROP_CHUNKS = new Set(['eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME']);
function stripPng(buf: Buffer): Buffer {
  const out: Buffer[] = [buf.subarray(0, 8)]; // signature
  let off = 8;
  while (off + 8 <= buf.length) {
    const len = buf.readUInt32BE(off);
    const end = off + 12 + len; // len(4) + type(4) + data(len) + crc(4)
    if (end > buf.length) throw new AiError('INPUT_REJECTED');
    const type = buf.toString('ascii', off + 4, off + 8);
    if (!PNG_DROP_CHUNKS.has(type)) out.push(buf.subarray(off, end));
    off = end;
    if (type === 'IEND') break;
  }
  return Buffer.concat(out);
}

// WEBP (RIFF): drop the EXIF and XMP chunks and clear their presence flags in
// the VP8X header so a strict decoder doesn't hunt for chunks that are gone.
function stripWebp(buf: Buffer): Buffer {
  const chunks: Buffer[] = [];
  let off = 12; // after "RIFF"<uint32 size>"WEBP"
  while (off + 8 <= buf.length) {
    const fourCC = buf.toString('ascii', off, off + 4);
    const size = buf.readUInt32LE(off + 4);
    const end = off + 8 + size + (size & 1); // chunks are padded to even length
    if (end > buf.length) throw new AiError('INPUT_REJECTED');
    if (fourCC !== 'EXIF' && fourCC !== 'XMP ') {
      if (fourCC === 'VP8X') {
        const vp8x = Buffer.from(buf.subarray(off, end));
        vp8x[8] &= ~0x0c; // clear EXIF (0x08) + XMP (0x04) flag bits
        chunks.push(vp8x);
      } else {
        chunks.push(buf.subarray(off, end));
      }
    }
    off = end;
  }
  const body = Buffer.concat(chunks);
  const header = Buffer.alloc(12);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(4 + body.length, 4); // "WEBP" + chunks
  header.write('WEBP', 8, 'ascii');
  return Buffer.concat([header, body]);
}

/** Returns the normalised declared mime on success; throws otherwise. */
function assertAllowedMedia(
  media: MediaPayload,
  allowed: readonly string[],
  maxBytes: number,
): string {
  if (
    !media ||
    !Buffer.isBuffer(media.bytes) ||
    media.bytes.length === 0 ||
    media.bytes.length > maxBytes
  ) {
    throw new AiError('INPUT_REJECTED');
  }
  const declared = normalizeMime(media.mimeType);
  if (!declared || !allowed.includes(declared)) {
    throw new AiError('INPUT_REJECTED');
  }
  return declared;
}

function normalizeMime(mimeType: unknown): string | null {
  if (typeof mimeType !== 'string') return null;
  const value = mimeType.split(';')[0]?.trim().toLowerCase();
  return value ? value : null;
}

function sniffImageMime(bytes: Buffer): string | null {
  if (
    bytes.length >= 3 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) {
    return 'image/jpeg';
  }
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return 'image/png';
  }
  if (
    bytes.length >= 12 &&
    bytes.toString('ascii', 0, 4) === 'RIFF' &&
    bytes.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}
