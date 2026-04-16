# Design Tokens

## tokens.json Schema

```json
{
  "colors": {
    "primary": { "50": "#eff6ff", "500": "#3b82f6", "900": "#1e3a5f" },
    "secondary": { "50": "...", "500": "...", "900": "..." },
    "neutral": { "0": "#ffffff", "50": "#f9fafb", "100": "#f3f4f6", "200": "#e5e7eb", "300": "#d1d5db", "400": "#9ca3af", "500": "#6b7280", "600": "#4b5563", "700": "#374151", "800": "#1f2937", "900": "#111827", "1000": "#000000" },
    "semantic": {
      "success": "#22c55e",
      "warning": "#f59e0b",
      "error": "#ef4444",
      "info": "#3b82f6"
    },
    "background": { "default": "#ffffff", "surface": "#f9fafb", "elevated": "#ffffff" },
    "text": { "primary": "#111827", "secondary": "#6b7280", "disabled": "#9ca3af", "inverse": "#ffffff" }
  },
  "typography": {
    "families": {
      "heading": "Inter, system-ui, sans-serif",
      "body": "Inter, system-ui, sans-serif",
      "mono": "JetBrains Mono, monospace"
    },
    "sizes": {
      "xs": "12px", "sm": "14px", "base": "16px", "lg": "18px",
      "xl": "20px", "2xl": "24px", "3xl": "32px", "4xl": "48px"
    },
    "weights": { "regular": 400, "medium": 500, "semibold": 600, "bold": 700 },
    "lineHeights": { "tight": 1.25, "normal": 1.5, "relaxed": 1.75 }
  },
  "spacing": {
    "1": "4px", "2": "8px", "3": "12px", "4": "16px",
    "6": "24px", "8": "32px", "12": "48px", "16": "64px"
  },
  "radii": { "sm": "4px", "md": "8px", "lg": "12px", "full": "9999px" },
  "shadows": {
    "sm": "0 1px 2px rgba(0,0,0,0.05)",
    "md": "0 4px 6px rgba(0,0,0,0.07)",
    "lg": "0 10px 15px rgba(0,0,0,0.1)"
  },
  "breakpoints": {
    "sm": "640px", "md": "768px", "lg": "1024px", "xl": "1280px"
  }
}
```

## Naming Conventions

- Flat keys in each category: `colors.primary.500`, not `color-primary-500`
- Semantic names over raw values: `text.primary`, not `gray-900`
- Numeric scales for ordered values (color shades, spacing)
- Named scales for discrete values (shadows, radii)

## Generating CSS Custom Properties

Convert tokens.json → CSS variables for use in components:

```css
:root {
  /* Colors */
  --color-primary-500: #3b82f6;
  --color-neutral-100: #f3f4f6;
  --color-text-primary: #111827;

  /* Typography */
  --font-heading: Inter, system-ui, sans-serif;
  --font-size-base: 16px;
  --font-weight-medium: 500;
  --line-height-normal: 1.5;

  /* Spacing */
  --space-4: 16px;
  --space-6: 24px;

  /* Radii */
  --radius-md: 8px;

  /* Shadows */
  --shadow-md: 0 4px 6px rgba(0,0,0,0.07);
}
```

Pattern: `--{category}-{path}` with hyphens replacing dots and nesting.

## Extracting Tokens from Existing Projects

**Tailwind config** → map `theme.extend.colors`, `theme.extend.spacing`, etc.

**CSS custom properties** → scan for `--` declarations in `:root` or `html`.

**SCSS variables** → scan for `$color-`, `$font-`, `$spacing-` patterns.

**Hardcoded values** → look for repeated hex colors, px values in component files.

When conflicts between sources exist, prefer: config file > custom properties > hardcoded values.

## Dark Mode Support (Optional)

If user requests dark mode, add a second token set:

```json
{
  "colors": { "...base tokens..." },
  "colorsDark": {
    "background": { "default": "#111827", "surface": "#1f2937", "elevated": "#374151" },
    "text": { "primary": "#f9fafb", "secondary": "#9ca3af" }
  }
}
```

Generate as `[data-theme="dark"]` selector overriding `:root` variables.
