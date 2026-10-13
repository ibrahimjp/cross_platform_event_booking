---
name: EventBook
colors:
  surface: '#f8f9ff'
  surface-dim: '#d0dbed'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e6eeff'
  surface-container-high: '#dee9fc'
  surface-container-highest: '#d9e3f6'
  on-surface: '#121c2a'
  on-surface-variant: '#494454'
  inverse-surface: '#27313f'
  inverse-on-surface: '#eaf1ff'
  outline: '#7b7486'
  outline-variant: '#cbc3d7'
  surface-tint: '#6d3bd7'
  primary: '#6b38d4'
  on-primary: '#ffffff'
  primary-container: '#8455ef'
  on-primary-container: '#fffbff'
  inverse-primary: '#d0bcff'
  secondary: '#5c5f60'
  on-secondary: '#ffffff'
  secondary-container: '#e1e3e4'
  on-secondary-container: '#626566'
  tertiary: '#855000'
  on-tertiary: '#ffffff'
  tertiary-container: '#a76500'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e9ddff'
  primary-fixed-dim: '#d0bcff'
  on-primary-fixed: '#23005c'
  on-primary-fixed-variant: '#5516be'
  secondary-fixed: '#e1e3e4'
  secondary-fixed-dim: '#c5c7c8'
  on-secondary-fixed: '#191c1d'
  on-secondary-fixed-variant: '#454748'
  tertiary-fixed: '#ffdcbb'
  tertiary-fixed-dim: '#ffb869'
  on-tertiary-fixed: '#2c1700'
  on-tertiary-fixed-variant: '#673d00'
  background: '#f8f9ff'
  on-background: '#121c2a'
  surface-variant: '#d9e3f6'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  container-max-width: 1280px
  gutter: 24px
  margin-desktop: 64px
  margin-mobile: 20px
  section-gap: 80px
---

## Brand & Style

The brand identity focuses on a high-end, AI-enabled concierge experience for event discovery and booking. It targets a professional audience that values efficiency, curation, and seamless execution. 

The design system employs a **Modern Corporate** style with **Glassmorphism** accents. The interface is characterized by a "High-Definition White" aesthetic—utilizing expansive white space to denote premium quality, paired with vibrant violet gradients to signal technological intelligence. UI elements feature soft, organic roundedness and subtle depth to make the platform feel approachable yet authoritative. AI-driven components should utilize slight translucency and animated gradients to differentiate themselves from static content.

## Colors

The palette is anchored by a sophisticated **Violet-to-Deep-Purple gradient** used exclusively for primary actions, AI status indicators, and branding moments. 

- **Primary:** Violet (#8B5CF6) acts as the energetic lead, while Deep Purple (#6D28D9) provides depth for hover states and active indicators.
- **Surface:** The UI relies on a "Pure White" (#FFFFFF) base for cards and containers, resting on a "Soft Gray" (#F9FAFB) background to create subtle layered separation.
- **Typography:** Deep Charcoal (#1F2937) is used for maximum legibility in body text, while a lighter slate tint is used for secondary metadata to maintain a clean visual hierarchy.
- **AI Accents:** Use a 15% opacity violet tint for background highlights in chat interfaces or recommendation blocks.

## Typography

This design system utilizes **Inter** for all roles to achieve a clean, systematic, and highly legible appearance. 

- **Headlines:** Use Bold (700) and Semi-Bold (600) weights with slightly tightened letter-spacing to create a sense of authority and modernity. 
- **Body Text:** Use Regular (400) weight. Paragraphs should maintain a generous line height (1.5x) to ensure readability against the bright white backgrounds.
- **Labels:** Use Medium (500) or Semi-Bold (600) weights. Small labels for "AI Recommended" or "Sold Out" tags should use uppercase with increased tracking for distinctiveness.

## Layout & Spacing

The layout follows a **12-column fluid grid** for desktop and a **single-column stack** for mobile. 

- **Rhythm:** All spacing is based on an 8px baseline grid. 
- **Vertical Spacing:** Use generous vertical padding (80px+) between major sections to emphasize the premium, "airy" feel.
- **Containerization:** Content should be centered in a max-width container of 1280px on desktop. On mobile, side margins should be a minimum of 20px to prevent content from feeling cramped against the screen edges.
- **AI Sidebar/Overlay:** The AI Chatbot should exist in a floating layer on the bottom right, with a consistent 24px inset from the screen edges.

## Elevation & Depth

Hierarchy is established through **Ambient Shadows** and **Tonal Layers**. 

- **Surface Level 0:** The base application background (#F9FAFB).
- **Surface Level 1 (Default Cards):** Pure white (#FFFFFF) with a very soft, diffused shadow: `0px 4px 20px rgba(31, 41, 55, 0.05)`.
- **Surface Level 2 (Hover/Active):** Slightly more pronounced shadow with a hint of the primary color: `0px 10px 30px rgba(139, 92, 246, 0.12)`.
- **Glassmorphism:** For AI recommendation overlays or navigation blurs, use a white background with 80% opacity and a 12px backdrop-filter (blur). This creates a "frosted" effect that feels futuristic and lightweight.

## Shapes

The shape language is organic and soft, reinforcing the "friendly expert" brand persona.

- **Standard Cards:** Use a 16px corner radius (`rounded-lg` in this system).
- **Buttons & Inputs:** Use a 12px radius to maintain consistency with the cards while appearing slightly more compact.
- **Interactive Tags/Chips:** Use full pill-shaped rounding (999px) for category tags or status indicators.
- **AI Components:** Elements generated by AI should feature slightly more aggressive rounding (24px) to distinguish them as "smart" and distinct from the standard layout.

## Components

### Buttons
- **Primary:** Solid gradient background (#8B5CF6 to #6D28D9) with white text. 12px radius. Subtle lift shadow on hover.
- **Secondary:** Transparent background with a 1px border of #8B5CF6 or a soft gray.
- **AI Action:** Features a subtle animated border or a small "sparkle" icon prefix.

### Cards
- Event cards must feature high-quality photography with a 16px top-corner radius.
- Use a 1px light gray border (#F3F4F6) only if the card rests on a pure white background; otherwise, rely on shadows for definition.

### Input Fields
- White background with a 1px border (#E5E7EB).
- Focus state: Border changes to #8B5CF6 with a 2px outer glow (ring) of the same color at 10% opacity.

### AI Chatbot & Recommendations
- The chat bubble should use the primary gradient for the user and a soft violet-tinted white for the AI.
- Recommendation chips should use a light violet background (#EDE9FE) with violet text.

### Lists & Navigation
- Top navigation bar should be sticky with a 20px blur backdrop-filter.
- List items for event results should feature generous padding (24px) and clear dividers using #F3F4F6.