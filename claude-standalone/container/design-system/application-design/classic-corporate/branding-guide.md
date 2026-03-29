## Page Screenshots

### Login Page

![Login Page](/api/projects/healthclean/assets/branding-screenshot-ch-c84c2fd9c-01-login-page.png)

### Dashboard

![Dashboard](/api/projects/healthclean/assets/branding-screenshot-ch-c84c2fd9c-02-dashboard.png)

### Scheduling - Task Assignment

![Scheduling - Task Assignment](/api/projects/healthclean/assets/branding-screenshot-ch-c84c2fd9c-03-scheduling-task-assignment.png)

### User Management

![User Management](/api/projects/healthclean/assets/branding-screenshot-ch-c84c2fd9c-04-user-management.png)

---

# Branding Guide — V1 Classic Corporate

## Overview
A clean, professional healthcare management interface featuring a stark white foundation with deep navy (#052252) as the primary anchor color. The design employs a corporate aesthetic with precise typographic hierarchy using Inter, subtle cyan (#00b2ee) accents for interactive states, and consistent gradient treatments for primary actions. The system prioritizes trustworthiness and operational clarity through generous whitespace, defined card containers, and methodical blue-toned color hierarchy.

## Color Palette

| Name | Hex Value | Usage |
|------|-----------|-------|
| **Primary** | `#052252` | Headers, primary buttons, navigation active states, key text hierarchy |
| **Primary Gradient End** | `#0a3a7a` | Button gradients, depth effects |
| **Secondary Blue** | `#0067b8` | Action buttons, tab active states, roster accents |
| **Accent/Cyan** | `#00b2ee` | Focus states, hover highlights, positive indicators, chart highlights |
| **Accent HSL** | `hsl(187 85% 43%)` | CSS variable for focus rings, underlines |
| **Background** | `#ffffff` | Primary canvas |
| **Surface Alt** | `#f8fafc` (slate-50) | Dashboard backgrounds, alternate sections |
| **Surface** | `#ffffff` | Cards, modals, popovers |
| **Text Primary** | `#0f172a` (slate-900) | Body text, headings |
| **Text Secondary** | `#475569` (slate-600) | Labels, descriptions, muted content |
| **Text Tertiary** | `#64748b` (slate-500) | Placeholders, timestamps, meta text |
| **Border** | `#e2e8f0` (slate-200) | Card borders, dividers, section separators |
| **Border Input** | `#cbd5e1` (slate-300) | Form field borders |
| **Destructive** | `hsl(0 84% 60%)` | Error states, deletion actions |
| **Success/Active** | `#00b2ee` | Status badges, notification dots, active indicators |
| **Avatar Gradient 1** | `#06b6d4` to `#2563eb` | User avatars (cyan-500 to blue-600) |
| **Avatar Gradient 2** | `#0067b8` to `#00b2ee` | Alternative avatar treatment |

### CSS Custom Properties
```css
:root {
  --background: 0 0% 100%;
  --foreground: 222 47% 11%;
  --card: 0 0% 100%;
  --card-foreground: 222 47% 11%;
  --popover: 0 0% 100%;
  --popover-foreground: 222 47% 11%;
  --primary: 217 87% 17%;        /* #052252 */
  --primary-foreground: 0 0% 100%;
  --secondary: 210 40% 96%;      /* slate-100 equivalent */
  --secondary-foreground: 222 47% 11%;
  --muted: 210 40% 96%;
  --muted-foreground: 215 16% 47%;
  --accent: 187 85% 43%;         /* Cyan accent */
  --accent-foreground: 222 47% 11%;
  --destructive: 0 84% 60%;
  --destructive-foreground: 0 0% 100%;
  --border: 214 32% 91%;         /* slate-200 equivalent */
  --input: 214 32% 91%;
  --ring: 217 87% 17%;           /* Primary focus rings */
  --radius: 0.5rem;              /* 8px base radius */
}
```

## Typography

### Font Stack
- **Primary**: `Inter, system-ui, -apple-system, sans-serif`
- **Weights**: 300 (Light), 400 (Regular), 500 (Medium), 600 (Semibold), 700 (Bold)
- **Loading**: Google Fonts with `display=swap`

### Type Scale

| Element | Size | Weight | Line Height | Letter Spacing | Usage |
|---------|------|--------|-------------|----------------|-------|
| **Page Title** | `30px` (text-3xl) | 700 (bold) | 1.2 | -0.025em (tracking-tight) | Page headers, H1 |
| **Section Title** | `24px` (text-2xl) | 600 (semibold) | 1.3 | -0.025em | Card headers, H2 |
| **Card Title** | `18px` (text-lg) | 600 (semibold) | 1.4 | normal | Subsection headers |
| **Body** | `14px` (text-sm) | 400 (normal) | 1.5 | normal | Paragraphs, descriptions |
| **Label** | `14px` (text-sm) | 500 (medium) | 1.4 | normal | Form labels, nav links |
| **Caption** | `12px` (text-xs) | 400 (normal) | 1.4 | normal | Meta text, timestamps |
| **Button** | `14px` (text-sm) | 600 (semibold) | 1 | normal | CTA text |
| **Logo Text** | `14px-18px` | 500-600 | 1 | normal | Product badges |

### Text Styling Patterns
- **Headings**: `text-slate-900` or explicit `#052252`, often with `tracking-tight`
- **Links**: Primary `#052252` default, cyan `#00b2ee` on hover with transition
- **Uppercase**: Not used; sentence case preferred throughout
- **Italics**: Not observed in standard UI text

## Spacing & Layout

### Base Unit
- **Tailwind Base**: 4px (0.25rem)
- **Common Scale**: 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px

### Container Specifications
- **Max Width**: `1280px` (max-w-7xl)
- **Horizontal Padding**: `16px` mobile (px-4), `24px` tablet (px-6), `32px` desktop (px-8)
- **Content Max Width**: `448px` (max-w-md) for centered auth forms

### Header Specifications
- **Height**: `64px` (h-16) for dashboard, `auto` with `24px` vertical padding for login
- **Border**: `1px solid #e2e8f0` (border-b border-slate-200)
- **Position**: `sticky top-0 z-50` with white background

### Section Rhythm
- **Section Spacing**: `32px` (py-8, mb-8)
- **Card Internal Padding**: `24px` (p-6)
- **Grid Gaps**: `24px` (gap-6) standard, `16px` (gap-4) compact
- **Form Field Spacing**: `20px` vertical (space-y-5)

### Responsive Breakpoints
- **SM**: 640px
- **MD**: 768px (grid switches: grid-cols-1 → md:grid-cols-2)
- **LG**: 1024px (lg:grid-cols-4 for metrics)
- **XL**: 1280px

## Imagery & Media Style

### Logo Treatment
- **Height**: `48px` (h-12) on login, `40px` (h-10) on dashboard
- **Layout**: Dual-logo pattern (icon + wordmark) with `16px` gap
- **Product Badge**: Separated by vertical divider (`w-px bg-slate-200` or `text-slate-300 |`)

### User Avatars
- **Size**: `32px` (w-8 h-8) compact, `36px` (w-9 h-9) standard
- **Shape**: `rounded-full` (circular)
- **Treatment**: Gradient backgrounds (cyan to blue), white text initials
- **Font**: Semibold, `14px` (text-sm)

### Icons
- **Source**: Heroicons (outline style)
- **Size**: `20px` (w-5 h-5) standard, `16px` (w-4 h-4) inline
- **Stroke Width**: `2` (stroke-width="2")
- **Color**: `text-slate-400` (inactive), `text-slate-600` (active), `text-blue-600` (accent contexts)
- **Input Icons**: Absolute positioned left, `20px` size, `12px` left padding (pl-3)

### Image Effects
- **Rounded Corners**: `8px` (rounded-lg) to `12px` (rounded-xl)
- **Shadows**: 
  - Cards: `0 8px 25px -5px rgba(0, 0, 0, 0.1), 0 4px 10px -5px rgba(0, 0, 0, 0.04)`
  - Buttons: `0 4px 12px hsl(217 87% 17% / 0.4)`
- **Borders**: `1px solid #e2e8f0` on cards and containers

## Component Patterns

### Buttons

**Primary Button**
```css
background: linear-gradient(135deg, #052252 0%, #0a3a7a 100%);
border-radius: 0.5rem;        /* 8px */
padding: 0.625rem 1rem;       /* 10px 16px (py-2.5 px-4) */
font-size: 0.875rem;          /* 14px */
font-weight: 600;             /* semibold */
color: white;
transition: all 0.2s ease-in-out;
/* Hover: translateY(-1px), shadow expansion */
/* Active: translateY(0) */
```

**Secondary Button**
```css
background: white;
border: 1px solid hsl(var(--border));  /* slate-200 */
border-radius: 0.5rem;
padding: 0.5rem 1rem;         /* py-2 px-4 */
font-size: 0.875rem;
font-weight: 500;
color: slate-700;
/* Hover: bg-slate-50, border-color transitions to accent */
```

**Ghost/Link Button**
- Text only with color transition: `#052252` to `#00b2ee` (cyan-600)
- No background or border
- Used for "Forgot password?" links

### Cards

**Standard Card**
```css
background-color: white;
border-radius: 0.75rem;       /* 12px (rounded-xl) */
border: 1px solid #e2e8f0;   /* slate-200 */
box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), /* shadow-sm default */
            0 8px 25px -5px rgba(0, 0, 0, 0.1); /* hover enhancement */
padding: 1.5rem;              /* 24px (p-6) */
/* Hover: translateY(-2px), enhanced shadow */
```

**Metric Card**
- Same as standard but with hover lift effect
- Icon container: `48px` (p-3) with `bg-blue-50` background, `rounded-lg`

### Forms

**Text Inputs**
```css
width: 100%;
padding: 0.625rem 0.75rem;     /* py-2.5 px-3 */
padding-left: 2.5rem;          /* 40px with icon (pl-10) */
border: 1px solid #cbd5e1;    /* slate-300 */
border-radius: 0.5rem;         /* 8px */
font-size: 0.875rem;           /* 14px */
color: #0f172a;               /* slate-900 */
/* Focus: border-color #00b2ee, box-shadow: 0 0 0 3px hsl(var(--accent) / 0.15) */
/* Transition: all 0.2s ease-in-out */
```

**Checkboxes**
- Size: `16px` (h-4 w-4)
- Accent color: `#052252` (text-[#052252])
- Border: `slate-300`
- Focus ring: `#052252` with `ring-offset-0`

**Labels**
- Display: block
- Margin bottom: `6px` (mb-1.5)
- Font: `14px` medium weight, `slate-700`

### Navigation

**Header Navigation**
- Layout: Flex with `32px` gap (gap-8)
- Links: `14px` medium weight
- Color: `slate-500` default, `slate-900` active
- Active indicator: Underline animation using `::after` pseudo-element
  - Height: `2px`
  - Color: `hsl(var(--accent))` (cyan)
  - Width animates 0→100% on hover/active
  - Position: `bottom: -2px`

**Mobile Behavior**
- Hidden below MD breakpoint (`hidden md:flex`)
- Hamburger menu not shown in provided HTML

### Tables

**Data Tables**
- Row hover: `background-color: hsl(210 40% 96% / 0.5)` (slate-50/50)
- Transition: `0.15s ease`
- Striping: Not observed (relying on hover states)
- Borders: Between rows using `border-b border-slate-100` or `border-slate-200`

### Badges & Status

**Status Badges**
- Rounded: `rounded-full` or `rounded-lg`
- Colors:
  - Active/Success: `#00b2ee` background or text
  - Notification dot: `#ef4444` (red-500) or `#06b6d4` (cyan-500)
- Padding: `2px-6px` typical
- Font: `12px` (text-xs) or `14px` (text-sm)

**Role Badges**
- Background: `slate-100` or subtle tints
- Border: `1px solid slate-200`
- Text: `slate-700`

### Tabs (Task Assignment Page)

**Tab Button**
```css
padding: 0.5rem 1rem;
border-radius: 0.5rem;
font-size: 0.875rem;
font-weight: 500;
transition: all 0.2s ease;
/* Active: background #0067b8, color white */
/* Inactive Hover: background slate-100, color #0067b8 */
```

## Overall Design Aesthetic

### Design Philosophy
**Corporate Healthcare Precision**: The system embodies institutional trust through conservative use of color, strict grid alignment, and clear typographic hierarchy. The deep navy primary (#052252) conveys stability and professionalism appropriate for healthcare environments, while the cyan accent (#00b2ee) provides modern, clinical energy without playfulness.

### Visual Weight & Density
- **Density**: Medium-low; generous whitespace (24px-32px) between sections prevents cognitive overload
- **Elevation**: Subtle shadow hierarchy—flat for static elements, `8px` blur shadows for hover states on cards
- **Borders**: Heavy use of `1px slate-200` borders to define containers without heavy visual weight
- **Information Hierarchy**: 
  - Primary: Deep navy text (#052252) or slate-900
  - Secondary: Slate-600/500 for descriptions
  - Tertiary: Icons in slate-400

### Mood & Emotional Tone
- **Trustworthy**: Conservative color palette, familiar Inter typeface, stable horizontal layouts
- **Clinical**: Cyan accents evoke medical/sterile environments; cleanliness through white backgrounds
- **Established**: Gradient buttons and shadow depth suggest sophistication and modern enterprise software
- **Approachable**: Rounded corners (8px-12px) soften the corporate rigidity

### Consistency Patterns
- **Gradient Consistency**: All primary actions use the same `135deg` gradient from `#052252` to `#0a3a7a`
- **Animation Language**: Uniform `0.2s ease-in-out` transitions across interactive elements; `0.6s ease-out` for page load fades
- **Focus States**: Consistent `3px` ring using accent color at `0.15` opacity, border color change to cyan
- **Border Radius**: `8px` (0.5rem) for interactive elements, `12px` (0.75rem) for cards/containers
- **Spacing System**: Tailwind's 4px base grid strictly adhered to (multiples of 4)

### Accessibility Considerations
- **Color Contrast**: Navy (#052252) on white exceeds WCAG AAA standards; slate-600 text maintains AA compliance
- **Focus Indicators**: Visible focus rings using `box-shadow` method (0 0 0 3px) with semi-transparent accent color
- **Touch Targets**: Buttons maintain minimum `40px` height (typically `40px` with py-2.5)
- **Form Labels**: Explicit `<label>` associations with `for` attributes
- **Iconography**: Decorative icons use `aria-hidden` or appropriate SVG attributes; functional icons paired with text labels
- **Typography**: Minimum `14px` for body text, `12px` only for meta/caption content

### Notable Inconsistencies
- **Header Height**: Login page uses taller header (`py-6` = 24px) vs dashboard (`py-4` = 16px)
- **Logo Sizing**: Login logo (`h-12` = 48px) larger than dashboard (`h-10` = 40px)
- **Background**: Login uses pure white (`bg-white`); Dashboard uses `bg-slate-50` (#f8fafc)
- **Avatar Gradients**: Three different gradient combinations observed across pages (cyan-blue, brand blues, cyan-cyan)
- **Product Name Treatment**: Sometimes separated by pipe character (`|`), sometimes by `div` with border, sometimes sized as `text-lg` vs `text-sm`