// Generates the Android launcher icon: a white spanner on the brand gradient.
//
// Pure Node — zlib is the only dependency and it ships with the runtime. Two
// other routes were tried and abandoned: ImageMagick is not installed, and
// rendering the app's own BrandMark widget through `flutter test` hangs, because
// the headless test environment has no rasterizer to answer `toImage`.
//
// The shapes are signed distance fields rather than polygons. That is what
// gives clean antialiased edges at 48px — a scanline polygon fill at that size
// produces visible stair-stepping on the diagonal handle, which is exactly
// where the eye lands on a spanner.
//
// Run: node tool/make_icon.js
const fs = require('fs')
const path = require('path')
const zlib = require('zlib')

// ── Brand ────────────────────────────────────────────────────────────────────
// AppTheme.headerGradient, top-left to bottom-right.
const GRADIENT = [
  [0x1e, 0x3a, 0x8a],
  [0x1d, 0x4e, 0xd8],
  [0x2f, 0x6b, 0xf0],
]
const STOPS = [0, 0.55, 1]

const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v)
const mix = (a, b, t) => a + (b - a) * t

function gradientAt(t) {
  t = clamp(t, 0, 1)

  for (let i = 1; i < STOPS.length; i++) {
    if (t <= STOPS[i]) {
      const local = (t - STOPS[i - 1]) / (STOPS[i] - STOPS[i - 1])
      return [0, 1, 2].map((c) => mix(GRADIENT[i - 1][c], GRADIENT[i][c], local))
    }
  }

  return GRADIENT[GRADIENT.length - 1]
}

// ── Signed distance helpers ──────────────────────────────────────────────────
// Negative inside, positive outside, magnitude in pixels — so a coverage value
// falls straight out of the distance and the edge antialiases itself.

function sdRoundedBox(px, py, cx, cy, halfW, halfH, r) {
  const qx = Math.abs(px - cx) - (halfW - r)
  const qy = Math.abs(py - cy) - (halfH - r)
  const ax = Math.max(qx, 0)
  const ay = Math.max(qy, 0)
  return Math.hypot(ax, ay) + Math.min(Math.max(qx, qy), 0) - r
}

/// Distance to a thick line segment with round caps.
function sdCapsule(px, py, ax, ay, bx, by, r) {
  const pax = px - ax
  const pay = py - ay
  const bax = bx - ax
  const bay = by - ay
  const h = clamp((pax * bax + pay * bay) / (bax * bax + bay * bay), 0, 1)
  return Math.hypot(pax - bax * h, pay - bay * h) - r
}

/// Distance to a ring of the given radius and thickness.
function sdRing(px, py, cx, cy, radius, thickness) {
  return Math.abs(Math.hypot(px - cx, py - cy) - radius) - thickness
}

/// Coverage from a distance: 1 inside, 0 outside, smooth across one pixel.
const coverage = (d) => clamp(0.5 - d, 0, 1)

/// Union of two distances — the nearer surface wins.
const union = (a, b) => Math.min(a, b)

/// Subtracts b from a.
const subtract = (a, b) => Math.max(a, -b)

// ── The mark ─────────────────────────────────────────────────────────────────

/**
 * A spanner, drawn diagonally across the tile.
 *
 * Head at the top-left, handle running to the bottom-right — the same reading
 * direction as the Material wrench the app draws in-widget, so the launcher and
 * the login screen show the same object.
 */
function spannerDistance(x, y, size) {
  const u = (v) => v * size

  // Handle: from just past the head down to the lower-right.
  const handle = sdCapsule(x, y, u(0.40), u(0.40), u(0.74), u(0.74), u(0.075))

  // Head: an open ring, its mouth facing up-left.
  const ring = sdRing(x, y, u(0.34), u(0.34), u(0.15), u(0.072))

  // The mouth — a capsule cut out of the ring, pointing away from the handle.
  const mouth = sdCapsule(x, y, u(0.34), u(0.34), u(0.14), u(0.14), u(0.088))

  return union(subtract(ring, mouth), handle)
}

// ── PNG encoding ─────────────────────────────────────────────────────────────

function encodePng(width, height, rgba) {
  const raw = Buffer.alloc((width * 4 + 1) * height)
  let o = 0

  for (let y = 0; y < height; y++) {
    raw[o++] = 0 // filter: none
    rgba.copy(raw, o, y * width * 4, (y + 1) * width * 4)
    o += width * 4
  }

  const chunk = (type, data) => {
    const len = Buffer.alloc(4)
    len.writeUInt32BE(data.length)
    const body = Buffer.concat([Buffer.from(type, 'ascii'), data])
    const crc = Buffer.alloc(4)
    crc.writeUInt32BE(crc32(body) >>> 0)
    return Buffer.concat([len, body, crc])
  }

  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(width, 0)
  ihdr.writeUInt32BE(height, 4)
  ihdr[8] = 8 // bit depth
  ihdr[9] = 6 // colour type: RGBA
  ihdr[10] = 0
  ihdr[11] = 0
  ihdr[12] = 0

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

let CRC_TABLE = null

function crc32(buf) {
  if (!CRC_TABLE) {
    CRC_TABLE = new Int32Array(256)
    for (let n = 0; n < 256; n++) {
      let c = n
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
      CRC_TABLE[n] = c
    }
  }

  let c = -1
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8)
  return c ^ -1
}

// ── Drawing ──────────────────────────────────────────────────────────────────

/**
 * @param size      pixel dimension
 * @param adaptive  transparent background, glyph inset for the launcher's mask
 */
function render(size, adaptive) {
  const px = Buffer.alloc(size * size * 4)

  // Android crops roughly the outer quarter of an adaptive foreground, so the
  // glyph is drawn into the middle and the rest left transparent. Without this
  // a circular mask would clip the ends off the spanner.
  const inset = adaptive ? size * 0.26 : 0
  const tile = size - inset * 2
  const radius = tile * 0.22

  // Supersampled 3×3. The tile corner and the ring both curve, and one sample
  // per pixel leaves them ragged at 48px.
  const S = 3

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let bgA = 0
      let glyphA = 0
      let rSum = 0
      let gSum = 0
      let bSum = 0

      for (let sy = 0; sy < S; sy++) {
        for (let sx = 0; sx < S; sx++) {
          const fx = x + (sx + 0.5) / S
          const fy = y + (sy + 0.5) / S

          // Tile
          let tileCov = 1
          if (!adaptive) {
            const d = sdRoundedBox(fx, fy, size / 2, size / 2, size / 2, size / 2, radius)
            tileCov = coverage(d)
          }

          if (tileCov > 0 && !adaptive) {
            const [r, g, b] = gradientAt((fx / size + fy / size) / 2)
            rSum += r * tileCov
            gSum += g * tileCov
            bSum += b * tileCov
            bgA += tileCov
          }

          // Glyph, in tile-local coordinates
          const gx = fx - inset
          const gy = fy - inset
          if (gx >= 0 && gy >= 0 && gx <= tile && gy <= tile) {
            glyphA += coverage(spannerDistance(gx, gy, tile))
          }
        }
      }

      const n = S * S
      const bg = bgA / n
      const glyph = clamp(glyphA / n, 0, 1)

      let r
      let g
      let b
      let a

      if (adaptive) {
        // White glyph on transparent.
        r = 255
        g = 255
        b = 255
        a = glyph
      } else {
        const br = bgA > 0 ? rSum / bgA : 0
        const bgg = bgA > 0 ? gSum / bgA : 0
        const bb = bgA > 0 ? bSum / bgA : 0

        // Glyph composited over the gradient.
        r = mix(br, 255, glyph)
        g = mix(bgg, 255, glyph)
        b = mix(bb, 255, glyph)
        a = bg
      }

      const o = (y * size + x) * 4
      px[o] = Math.round(clamp(r, 0, 255))
      px[o + 1] = Math.round(clamp(g, 0, 255))
      px[o + 2] = Math.round(clamp(b, 0, 255))
      px[o + 3] = Math.round(clamp(a, 0, 1) * 255)
    }
  }

  return encodePng(size, size, px)
}

// ── Output ───────────────────────────────────────────────────────────────────

const RES = 'android/app/src/main/res'

const LEGACY = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
}

for (const [folder, size] of Object.entries(LEGACY)) {
  const dir = path.join(RES, folder)
  fs.mkdirSync(dir, { recursive: true })

  fs.writeFileSync(path.join(dir, 'ic_launcher.png'), render(size, false))
  // The adaptive foreground is 108dp at the same density, of which 72dp is the
  // safe zone. Written per-density so the launcher picks the right one.
  fs.writeFileSync(
    path.join(dir, 'ic_launcher_foreground.png'),
    render(Math.round(size * 2.25), true),
  )

  console.log(`${folder}  ${size}x${size}  + foreground`)
}

console.log('\ndone')
