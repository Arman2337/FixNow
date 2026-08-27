import { stripImageMetadata } from './ai-media-policy';

/** FF <marker> <uint16be length incl. these 2 bytes> <payload>. */
function jpegSeg(marker: number, payload: Buffer): Buffer {
  const len = Buffer.alloc(2);
  len.writeUInt16BE(payload.length + 2);
  return Buffer.concat([Buffer.from([0xff, marker]), len, payload]);
}

/** <uint32be length> <type> <data> <4-byte CRC placeholder>. */
function pngChunk(type: string, data: Buffer): Buffer {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  return Buffer.concat([len, Buffer.from(type, 'ascii'), data, Buffer.alloc(4)]);
}

/** <FourCC> <uint32le size> <data> <pad to even>. */
function webpChunk(fourCC: string, data: Buffer): Buffer {
  const size = Buffer.alloc(4);
  size.writeUInt32LE(data.length);
  const pad = data.length & 1 ? Buffer.alloc(1) : Buffer.alloc(0);
  return Buffer.concat([Buffer.from(fourCC, 'ascii'), size, data, pad]);
}

function webp(chunks: Buffer[]): Buffer {
  const body = Buffer.concat(chunks);
  const header = Buffer.alloc(12);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(4 + body.length, 4);
  header.write('WEBP', 8, 'ascii');
  return Buffer.concat([header, body]);
}

const PNG_SIG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const has = (buf: Buffer, text: string) =>
  buf.includes(Buffer.from(text, 'ascii'));

describe('stripImageMetadata', () => {
  it('drops the JPEG EXIF/APP1 segment but keeps JFIF, pixels and structure', () => {
    const jpeg = Buffer.concat([
      Buffer.from([0xff, 0xd8]), // SOI
      jpegSeg(0xe1, Buffer.from('Exif\x00\x00GPS-SECRET-28.61N')), // APP1 EXIF
      jpegSeg(0xe0, Buffer.from('JFIF\x00\x01\x01')), // APP0 JFIF (keep)
      jpegSeg(0xdb, Buffer.from([1, 2, 3, 4])), // DQT (keep)
      Buffer.from([0xff, 0xda, 0x00, 0x02]), // SOS (no scan payload)
      Buffer.from([0x12, 0x34]), // entropy data
      Buffer.from([0xff, 0xd9]), // EOI
    ]);

    const out = stripImageMetadata({ bytes: jpeg, mimeType: 'image/jpeg' });

    expect(has(out.bytes, 'GPS-SECRET-28.61N')).toBe(false);
    expect(has(out.bytes, 'JFIF')).toBe(true); // colour/base segment kept
    expect(out.bytes.subarray(0, 2)).toEqual(Buffer.from([0xff, 0xd8])); // SOI
    expect(out.bytes.subarray(-2)).toEqual(Buffer.from([0xff, 0xd9])); // EOI
    expect(has(out.bytes, '\x124')).toBe(true); // entropy bytes 0x12 0x34 intact
    // Idempotent: a second pass is a no-op.
    expect(stripImageMetadata(out).bytes).toEqual(out.bytes);
  });

  it('leaves a JPEG with no metadata segments byte-identical', () => {
    const clean = Buffer.concat([
      Buffer.from([0xff, 0xd8]),
      jpegSeg(0xe0, Buffer.from('JFIF\x00')),
      Buffer.from([0xff, 0xda, 0x00, 0x02, 0xaa, 0xff, 0xd9]),
    ]);
    const out = stripImageMetadata({ bytes: clean, mimeType: 'image/jpeg' });
    expect(out.bytes).toEqual(clean);
  });

  it('drops PNG text/eXIf chunks but keeps IHDR/IDAT/IEND', () => {
    const png = Buffer.concat([
      PNG_SIG,
      pngChunk('IHDR', Buffer.alloc(13)),
      pngChunk('tEXt', Buffer.from('Comment\x00SECRET-CAPTION')),
      pngChunk('eXIf', Buffer.from('II\x2a\x00GPS-SECRET')),
      pngChunk('IDAT', Buffer.from([9, 9, 9])),
      pngChunk('IEND', Buffer.alloc(0)),
    ]);

    const out = stripImageMetadata({ bytes: png, mimeType: 'image/png' });

    expect(has(out.bytes, 'SECRET-CAPTION')).toBe(false);
    expect(has(out.bytes, 'GPS-SECRET')).toBe(false);
    expect(out.bytes.subarray(0, 8)).toEqual(PNG_SIG);
    for (const kept of ['IHDR', 'IDAT', 'IEND']) {
      expect(has(out.bytes, kept)).toBe(true);
    }
  });

  it('drops WEBP EXIF/XMP chunks and clears the VP8X presence flags', () => {
    const vp8xData = Buffer.alloc(10);
    vp8xData[0] = 0x0c; // EXIF (0x08) + XMP (0x04) flags advertised
    const input = webp([
      webpChunk('VP8X', vp8xData),
      webpChunk('VP8 ', Buffer.from([1, 2, 3, 4])), // real pixel payload (keep)
      webpChunk('EXIF', Buffer.from('GPS-SECRET')),
      webpChunk('XMP ', Buffer.from('XMP-SECRET-AUTHOR')),
    ]);

    const out = stripImageMetadata({ bytes: input, mimeType: 'image/webp' });

    expect(has(out.bytes, 'GPS-SECRET')).toBe(false);
    expect(has(out.bytes, 'XMP-SECRET-AUTHOR')).toBe(false);
    expect(has(out.bytes, 'VP8 ')).toBe(true); // pixel chunk survives
    expect(out.bytes[20]).toBe(0); // VP8X flags byte (12 header + 8) cleared
    // RIFF size field stays consistent with the rebuilt file.
    expect(out.bytes.readUInt32LE(4)).toBe(out.bytes.length - 8);
  });

  it('forwards a synthetic magic-bytes payload unchanged (best-effort, not a validator)', () => {
    // The eval / deterministic-provider convention is JPEG magic + trailing
    // text. The stripper cleans what it can parse and passes the rest through
    // untouched; `assertAllowedImage` is the gatekeeper that rejects bad input,
    // not this function.
    const synthetic = Buffer.concat([
      Buffer.from([0xff, 0xd8, 0xff]),
      Buffer.from(' pipe leaking under the sink'),
    ]);
    const out = stripImageMetadata({ bytes: synthetic, mimeType: 'image/jpeg' });
    expect(out.bytes).toEqual(synthetic);
  });
});
