import * as zlib from "zlib";
import { promisify } from "util";

const gunzip = promisify(zlib.gunzip);
const inflate = promisify(zlib.inflate);
const inflateRaw = promisify(zlib.inflateRaw);

/**
 * Decompress request body based on Content-Encoding header.
 *
 * The iOS SDK uses NSData.compressed(using: .zlib) which produces **raw deflate**
 * data (no zlib/gzip wrapper), but sends Content-Encoding: gzip.
 * We try each decompression method in order rather than relying on magic bytes,
 * since raw deflate data can start with any byte value.
 */
export async function decompressBody(
  body: Buffer,
  contentEncoding?: string
): Promise<Buffer> {
  if (!contentEncoding) {
    return body;
  }

  const encoding = contentEncoding.toLowerCase();
  if (encoding !== "gzip" && encoding !== "deflate" && encoding !== "zlib") {
    return body;
  }

  if (body.length < 2) return body;

  // Try each format in order: raw deflate (what the SDK actually sends),
  // then zlib-wrapped, then gzip. Fall back to raw body if all fail.
  try {
    return await inflateRaw(body);
  } catch {
    // not raw deflate
  }

  try {
    return await inflate(body);
  } catch {
    // not zlib-wrapped
  }

  try {
    return await gunzip(body);
  } catch {
    // not gzip
  }

  // All decompression failed — return raw body (might be uncompressed JSON)
  return body;
}
