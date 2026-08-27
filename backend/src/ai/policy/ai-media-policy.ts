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

export function assertAllowedAudio(
  media: MediaPayload,
  maxBytes: number,
): void {
  // Audio containers are too varied to sniff reliably; mime + size + non-empty
  // is the bound here. Whisper itself rejects genuinely undecodable audio.
  assertAllowedMedia(media, ALLOWED_AUDIO_MIME_TYPES, maxBytes);
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
