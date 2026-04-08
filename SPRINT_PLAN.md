# ZPS World — Sprint Plan
## Gamified Virtual Office · Prototype to Production
*Updated: April 2026 · v0.2*

---

## Vision
A top-down 2D (expandable to 3D) virtual office where ZPS members:
- Move around as their avatar in a digital twin of the real office
- Interact with colleagues, get AI agent replies when they're offline
- Book meeting rooms, apply for leave, view sprint status — all in-world
- Customize their desk and avatar (outfits, accessories earned via ZPS Member achievements)

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│              GODOT 4 CLIENT                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  World   │  │  Player  │  │   UI     │  │
│  │  Engine  │  │  Avatar  │  │  Panels  │  │
│  └──────────┘  └──────────┘  └──────────┘  │
│         ↕ HTTP/WebSocket API                │
└─────────────────────────────────────────────┘
         ↕
┌─────────────────────────────────────────────┐
│              BACKEND API                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │   Auth   │  │  HR Data │  │  Rooms   │  │
│  │   SSO    │  │  Sync    │  │ Booking  │  │
│  └──────────┘  └──────────┘  └──────────┘  │
│  ┌──────────┐  ┌──────────┐                │
│  │   AI     │  │  Task    │                │
│  │  Agent   │  │ Manager  │                │
│  └──────────┘  └──────────┘                │
└─────────────────────────────────────────────┘
```

---

## Sprint 0 — Foundation ✅ COMPLETE
**Duration:** Week 1-2

- [x] Project structure, autoloads, scene system
- [x] GameManager (global state, event bus, mock data for 16 employees)
- [x] PlayerData (avatar config, outfit rotation by day, AI agent context)
- [x] AIAgent (Claude API + mock mode with pattern-matched fallback)
- [x] Player.gd (self-contained: visuals built in _ready, movement, interaction)
- [x] CameraController (mouse drag-to-pan, scroll zoom 0.8x–4x, F to snap home)
- [x] 200-seat office floor plan (120×96 tiles):
  - 6 department zones (Engineering, Design, Product, HR, Data, Marketing)
  - 5 meeting rooms + Boardroom (wall-separated with door cutouts)
  - Pantry/Kitchen (counter, sink, fridge, dining tables)
  - Recreation lounge (sofas, ping-pong, game consoles)
  - Reception lobby
- [x] HUD + notification toasts (fully programmatic, no scene files)
- [x] Interaction dialog (chat + AI agent replies)
- [x] Avatar customizer + Workspace panel

---

## Sprint 1 — Asset Integration (CURRENT)
**Duration:** Week 3-4
**Goal:** Replace ColorRect placeholders with real pixel art assets

### Free CC0/CC-BY Asset Sources to Download

| Pack | Source | License | Use For |
|------|--------|---------|---------|
| Kenney Top-Down Shooter | kenney.nl/assets/top-down-shooter | CC0 | Character sprites |
| Kenney Tiny Town | kenney.nl/assets/tiny-town | CC0 | Office furniture |
| LPC Office Furniture | opengameart.org/content/lpc-office-furniture | CC0 | Desks, chairs |
| Pipoya Modern Office | itch.io/pipoya-office | CC0 | Full office tileset |

### Multi-Agent Task Breakdown

Each agent works on a separate subsystem — no file conflicts:

| Agent | File(s) | Task |
|-------|---------|------|
| **World Agent** | `Office.gd`, `OfficeLayout.gd` | TileMap setup, room colliders, lighting zones |
| **Avatar Agent** | `Player.gd`, `Employee.gd`, `AvatarRenderer.gd` | Sprite2D swap, 4-dir walk animation |
| **Asset Agent** | `assets/sprites/*`, `assets/tilesets/*` | Download, slice, import textures to Godot |
| **UI Agent** | `HUD.gd`, `WorkspacePanel.gd` | Visual polish, icon assets, better layout |
| **NPC Agent** | `Employee.gd`, AI wander logic | Idle animations, patrol paths, contextual emotes |

### Sprint 1 Tasks
- [ ] Download Kenney Top-Down + Tiny Town packs
- [ ] Import tileset PNG as TileSet resource, paint office floor in TileMap
- [ ] Replace player ColorRect with Sprite2D (Kenney character sheet)
- [ ] Add AnimationPlayer: idle/walk_left/walk_right/walk_up/walk_down
- [ ] Replace NPC ColorRect with Sprite2D + color modulation per department
- [ ] Add furniture sprites at desk positions
- [ ] Add room boundary CollisionShape2D walls (invisible, physics layer)
- [ ] Meeting room doors: Area2D trigger → show booking dialog when entered

---

## Sprint 2 — Multiplayer (Real-time Presence)
**Duration:** Week 5-7
**Goal:** Real users see each other moving in the same office

### Architecture: WebSocket Server
```
Godot Client ←→ Node.js WebSocket Server ←→ All Godot Clients
```

### Multi-Agent Breakdown

| Agent | Owns |
|-------|------|
| **Server Agent** | Node.js WS server: position sync, chat relay, presence |
| **Client Agent** | Godot MultiplayerAPI: peer join/leave, interpolation |
| **State Agent** | PlayerData → server sync: outfit, callsign, task status |
| **AI Handoff Agent** | Disconnect → AIAgent mode transition logic |

### Tasks
- [ ] WebSocket server (Node.js `ws` library, 50ms tick)
- [ ] Position interpolation on client (lerp to predicted position)
- [ ] Online roster panel (live green dots, last seen)
- [ ] Chat bubbles above characters, persistent chat log panel
- [ ] Disconnect → AI agent takes over (character stays visible, replies as AI)

---

## Sprint 3 — Backend Integration
**Duration:** Week 8-10
**Goal:** Real HR data, real room booking, sprint sync

### Multi-Agent Breakdown

| Agent | Owns |
|-------|------|
| **API Agent** | NestJS REST API design + routes |
| **HR Agent** | Employee data sync from HR system → `employees` table |
| **Room Agent** | Room booking persistence (PostgreSQL) + conflict detection |
| **Task Agent** | Sprint/task webhook from ZPS Task Manager |
| **Auth Agent** | SSO integration → JWT token |

---

## Sprint 4 — Avatar Depth + Desk Decoration
**Duration:** Week 11-12

### Multi-Agent Breakdown

| Agent | Owns |
|-------|------|
| **Outfit Agent** | Full layered outfit system (body + outfit + accessory + cape + pet + aura) |
| **Desk Agent** | Desk decoration mode (D key at desk → item placement grid) |
| **Achievement Agent** | ZPS Member achievement sync → cosmetic unlocks |
| **Preview Agent** | 3D profile card (WebGL rotating avatar) |

---

## Sprint 5 — Events, Courses, Lecture Hall
**Duration:** Week 13-15

- [ ] Seasonal event system (office decorates for events)
- [ ] Course registration room (connect to LMS)
- [ ] Lecture hall (NPC presenter, audience seating)
- [ ] Meeting room door calendar view
- [ ] Cafeteria social zone with ambient NPCs

---

## Sprint 6 — ZPS World 3D (Future)
**Duration:** TBD

| Option | Recommended? |
|--------|-------------|
| Godot 3D | ✅ Same engine, same autoloads |
| Three.js web | Browser-native, no install |
| VRM Avatar system | Standard format, works in Godot via plugin |

---

## Controls Reference

| Key | Action |
|-----|--------|
| WASD / Arrow Keys | Move |
| Shift + WASD | Run |
| E | Interact |
| H | Workspace Panel |
| Shift + A | Avatar Customizer |
| F | Camera: snap back to player |
| Mouse Drag | Camera pan |
| Scroll Wheel | Zoom (0.8x – 4.0x) |

---

## File Structure

```
ZPSWorld/
├── project.godot
├── SPRINT_PLAN.md
├── scripts/
│   ├── autoloads/
│   │   ├── GameManager.gd     ← 16 employees, 5 rooms, event bus
│   │   ├── PlayerData.gd      ← Avatar config, outfit rotation
│   │   └── AIAgent.gd         ← Claude API + mock mode
│   ├── player/Player.gd       ← Self-contained, builds own nodes
│   ├── npc/Employee.gd
│   ├── world/
│   │   ├── Office.gd          ← 120×96 tile, 200-seat layout
│   │   └── CameraController.gd ← Drag-pan, zoom, snap-home
│   └── ui/
│       ├── HUD.gd
│       ├── InteractionDialog.gd
│       ├── AvatarCustomizer.gd
│       └── WorkspacePanel.gd
└── assets/                    ← Add pixel art packs here (Sprint 1)
    ├── tilesets/
    └── sprites/
```
