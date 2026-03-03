import * as zlib from "zlib";

/**
 * Decompress request body based on Content-Encoding header.
 * The SDK uses NSData.compressed(using: .zlib) which produces zlib-format data,
 * but sends Content-Encoding: gzip. We handle both formats.
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

  // Detect format from first two bytes
  if (body.length < 2) return body;

  const firstByte = body[0];
  const secondByte = body[1];

  return new Promise((resolve, reject) => {
    // 0x1f 0x8b = gzip format
    if (firstByte === 0x1f && secondByte === 0x8b) {
      zlib.gunzip(body, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    }
    // 0x78 = zlib format (what the SDK actually sends)
    else if (firstByte === 0x78) {
      zlib.inflate(body, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      });
    }
    // Try raw deflate as fallback
    else {
      zlib.inflateRaw(body, (err, result) => {
        if (err) {
          // If all decompression fails, return raw body
          resolve(body);
        } else {
          resolve(result);
        }
      });
    }
  });
}
