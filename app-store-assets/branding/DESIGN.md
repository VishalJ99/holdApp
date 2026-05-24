---
version: alpha
name: "Hold"
colors:
  primary: "#1F2747"
  dark: "#1F2937"
  white: "#FFFFFF"
  color-800: "#171D35"
  color-700: "#1F2747"
  color-600: "#36447C"
  color-500: "#4658A0"
  color-400: "#5F71B9"
  color-300: "#8391C9"
  color-200: "#A6B0D8"
  color-100: "#CAD0E8"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.white}"
  button-primary-hover:
    backgroundColor: "{colors.color-600}"
    textColor: "{colors.white}"
  button-secondary:
    backgroundColor: "{colors.white}"
    textColor: "{colors.primary}"
  button-secondary-hover:
    backgroundColor: "{colors.white}"
    textColor: "{colors.color-600}"
---

## Overview

Brand kit and design tokens for **Hold**. This file follows the [design.md](https://github.com/google-labs-code/design.md) format introduced by Google in 2025. Drop it into your project root alongside the asset files in this ZIP so AI coding agents (Claude Code, Cursor, Cowork, etc.) can generate UI that matches the **Hold** brand.

Designed by [Anymark](https://anymark.co) on 2026-05-23.

## Brand Kit Files

These files ship alongside this `DESIGN.md` in the ZIP. Pick the right asset for the context instead of regenerating logos.

### Master logo

| File | What it is | When to use |
| --- | --- | --- |
| `hold_logo.svg` | Primary logo, vector, transparent | Default. Any target that supports SVG (web, Figma, modern docs). |
| `hold_logo.png` | Primary logo, raster, transparent | Raster contexts on light / white backgrounds. |
| `hold_logo_white.png` | White logo, raster, transparent | Dark backgrounds, photos, or any low-contrast surface. |

### Icon only

| File | What it is | When to use |
| --- | --- | --- |
| `hold_icon_color.png` | Icon in brand color, transparent | Square slots, inline marks, app tiles. |
| `hold_icon_white.png` | Icon in white, transparent | Dark or photo backgrounds, mark only. |

### Platform-ready

| File | What it is | When to use |
| --- | --- | --- |
| `hold_favicon.ico` | ICO favicon | Drop into website root as `/favicon.ico`. |
| `hold_social_icon.png` | Icon on white background | Profile picture when a light avatar reads best. |
| `hold_inverse_avatar.png` | Icon on brand-color background | Profile picture when a colored avatar reads best. |

### Social covers

- `social-covers/social-cover1.jpg`, `social-covers/social-cover2.jpg` — general-purpose banners.
- `social-covers/dark/social-cover-dark1.jpg` through `social-cover-dark4.jpg` — banners tuned to the **dark** color family.

## Colors

### Primary tokens

- **primary** (`#1F2747`) — Primary brand color. CTAs, active states, highlights, key brand moments.
- **dark** (`#1F2937`) — Body text, borders, elements that need maximum readability.
- **white** (`#FFFFFF`) — Backgrounds, negative space, clean minimal layouts.

### Extended palette (generated shades)

- **color-800** (`#171D35`) — Darkest shade. Emphatic text on light.
- **color-700** (`#1F2747`) — Active / pressed states, emphasis. _(matches `primary` — the brand color)_
- **color-600** (`#36447C`) — Hover state for primary CTAs.
- **color-500** (`#4658A0`) — Mid tone. Generic accents and fills.
- **color-400** (`#5F71B9`) — Secondary accents.
- **color-300** (`#8391C9`) — Disabled states, muted accents.
- **color-200** (`#A6B0D8`) — Hover on light surfaces, dividers.
- **color-100** (`#CAD0E8`) — Lightest tint. Page backgrounds, subtle surfaces.

### Status badges

Any pairing of two colors from {primary, `color-100`–`color-700`, `#1F2937`, `#FFFFFF`} that reaches a 6:1 contrast ratio works as a badge. Typical pairs:

- Dark pill: background `#1F2937` or `color-800`, text `#FFFFFF` or a light palette tint.
- Tinted pill: background `color-100` / `color-200`, text `color-700` / `color-800`.
- Brand pill: background `primary` (`#1F2747`), text `#FFFFFF`. Only if the pair passes 6:1.

### Contrast note

Check WCAG AA contrast (4.5:1) before you ship. Anymark does not certify specific combinations.

## Components

Buttons are defined as tokens in the frontmatter above (`button-primary`, `button-primary-hover`, `button-secondary`, `button-secondary-hover`). Only `backgroundColor` and `textColor` are specified. Padding, radius, and typography are intentionally left to the consumer's design system.

We pick shades that hit WCAG AA contrast (4.5:1) against their paired text or background color. Verify before use. If the raw `primary` color does not pass 4.5:1 against white, the tokens reference a darker palette shade (`color-600`, `color-700`, or `color-800`) instead.

## Do's and Don'ts

### Do

- Use `hold_logo.svg` whenever the target supports vector. Fall back to PNG if any issues with SVG are found or if the customer requests it.
- Use `hold_logo_white.png` on dark or photo backgrounds.
- Keep clear space around the logo equal to at least the height of the icon.
- Reserve the `primary` color for primary CTAs, active states, and brand moments. Primary tokens (`primary`, `dark`, `white`) should cover ~80% of surfaces.
- Verify contrast when combining any two tokens from the extended palette.

### Don't

- Don't rotate the logo.
- Don't stretch, squash, or distort the proportions.
- Don't add gradients, shadows, outlines, or strokes to the logo.
- Don't recolor the logo outside this palette.
- Don't place the logo on low-contrast or visually cluttered backgrounds.
- Don't swap horizontal for vertical layout, or remove the icon.
- Don't use the primary color decoratively. Treat it as a functional accent.
