/**
 * Bounded validation for media that crosses the AI provider boundary (FN-058
 * audio, FN-059 images). Enforces a mime allow-list, a byte ceiling, and
 * non-emptiness; for images it additionally sniffs magic bytes and requires
 * them to match the declared type, so a mislabelled or disguised payload is
 * rejected before any provider call. Rejections are `INPUT_REJECTED`.
 *
 * Scope boundary (ADR-0014 release gate): production image handling also
 * requires EXIF stripping and malware scanning before external transfer. Those
 * hooks are intentionally NOT implemented here — see
 * `docs/ai/problem-classification.md`. This module is content-shape validation,
 * not sanitisation.
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
