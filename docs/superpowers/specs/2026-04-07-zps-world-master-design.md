# ZPS World — Master Design Document

| Field | Value |
|-------|-------|
| **Version** | 1.0 |
| **Date** | 2026-04-07 |
| **Status** | Approved |
| **Engine** | Godot 4 (GDScript) |
| **Platform** | Web-first (HTML5/WASM) + Desktop optional |
| **Audience** | All ZPS members — reads in two layers: Vision (Part 1) for stakeholders, Blueprint (Part 2) for builders |

---

# PART 1 — VISION DOC

## 1.1 Elevator Pitch

ZPS World là **virtual office dạng game** của ZPS — nơi toàn bộ thành viên công ty hiện diện, làm việc, tương tác và trải nghiệm văn hóa ZPS thông qua một lớp game-like. Không chỉ là avatar đi lại trong văn phòng ảo, ZPS World còn là **single entry point** cho mọi tool: HR, task management, AI agents, admin tools — tất cả được tích hợp trực tiếp vào thế giới game.

Mở trình duyệt → đăng nhập SSO → avatar của bạn xuất hiện tại bàn làm việc. Đồng nghiệp đang online di chuyển trong thế giới. Đồng nghiệp offline trở thành NPC thông minh. Senior và Lead trở thành "NPC cao cấp" với vùng lãnh thổ và công cụ riêng của họ.

**Quan trọng: Game layer là overlay tùy chọn, không phải bắt buộc.** Mỗi tool trong ZPS World đều có thể truy cập độc lập qua URL hoặc direct link — không cần đi qua game world. Người dùng không thích game interface vẫn dùng được HR Tool, Task Manager, AI Agent như bình thường. ZPS World là lớp trải nghiệm được thêm vào *trên* các tool đó, không thay thế chúng.

Sau khi export dưới dạng web (WASM), ZPS World được **embed như một tab trong workspace chính** của công ty — cùng với các tab tool khác. Không cần mở cửa sổ riêng, không cần cài đặt thêm.

## 1.2 Vấn Đề Đang Giải Quyết

| Pain Point | Biểu hiện hiện tại | ZPS World giải quyết bằng |
|-----------|-------------------|--------------------------|
| **Tool phân tán** | HR tool, task manager, AI agent, admin ở nhiều nơi | Tích hợp tất cả vào một world duy nhất |
| **Mất kết nối xã hội** | Remote/hybrid làm loãng văn hóa công ty | Virtual presence — thấy nhau di chuyển, chat bubble, emote |
| **Knowledge bị lock** | Senior/Lead knowledge trong đầu, khó chia sẻ | Super NPC mode: AI đại diện khi họ offline, có đầy đủ context |
| **Onboarding chậm** | Newbie không biết ai là ai, tool nào ở đâu | Bản đồ thế giới = org chart sống, tool zones rõ ràng |
| **Tool adoption thấp** | UX tool kém, không ai muốn mở | Truy cập tool qua game interaction → tự nhiên hơn |

## 1.3 Four Core Pillars

```
┌─────────────────────────────────────────────────────────────┐
│                         ZPS WORLD                          │
├────────────────┬────────────────┬───────────────┬──────────┤
│  🌐 Virtual    │  🛠 Tool Hub   │  🎮 Game      │ 🤝 Social│
│  Workplace     │                │  Layer        │ Fabric   │
├────────────────┼────────────────┼───────────────┼──────────┤
│ Digital twin   │ AI Agents      │ Avatar system │ Proximity│
│ văn phòng ZPS  │ HR Tool        │ Achievements  │ chat     │
│ Presence &     │ Task Manager   │ Events        │ Emotes   │
│ desk system    │ Admin Tool     │ Minigames     │ Status   │
│ Meeting rooms  │ Room Booking   │ Cosmetics     │ DM panel │
└────────────────┴────────────────┴───────────────┴──────────┘
```

- **Virtual Workplace**: Digital twin của văn phòng ZPS. Mỗi nhân viên có bàn, mỗi phòng có chức năng thực tế.
- **Tool Hub**: Tất cả tool công ty đều truy cập được từ trong world — không cần tab mới. Đồng thời mỗi tool vẫn hoạt động độc lập qua direct URL cho người dùng không dùng game layer.
- **Game Layer**: Avatar, cosmetics, events, minigames tạo engagement tự nhiên mà không cần cày cuốc. Đây là overlay tùy chọn — không ảnh hưởng đến người dùng không muốn trải nghiệm game.
- **Social Fabric**: Proximity chat, emote, presence awareness kết nối mọi người bất kể remote hay on-site.

## 1.4 Ai Sẽ Dùng & Dùng Như Thế Nào

| Persona | Cách dùng hàng ngày |
|---------|---------------------|
| **Regular Employee** | Đăng nhập → thấy ai online → chat/interact → dùng tool qua world → tham gia event |
| **Senior / Lead** | Manage tool zone của mình → giao task trong game → trở thành NPC khi offline |
| **New Employee** | Onboarding qua world map = học được org chart sống, tìm được đúng người, đúng tool |
| **HR / Admin** | Tạo company-wide event, manage announcements, xem presence analytics |

## 1.5 Success Metrics

| Metric | Target (6 tháng sau launch) |
|--------|----------------------------|
| Weekly Active Users | ≥ 80% total headcount |
| Tool usage qua ZPS World | ≥ 60% các tool request đi qua world |
| NPC interaction | ≥ 50 queries/ngày tổng cộng |
| Event attendance | ≥ 70% tham dự official events |
| Avatar customization | ≥ 90% employees có avatar đã customize |

## 1.6 High-Level Architecture Map

```
┌────────────────────────────────────────────────────┐
│                   ZPS WORLD CLIENT                 │
│          Godot 4 — Web (WASM) + Desktop            │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │  World   │  │  Player  │  │   Tool Panels    │  │
│  │  Engine  │  │  Avatar  │  │  (HR/Task/AI/..) │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
└────────────────────┬───────────────────────────────┘
         WebSocket (realtime) │ REST (data)
┌────────────────────┴───────────────────────────────┐
│                    BACKEND                         │
│  Node.js WS Server        NestJS REST API          │
│  ┌─────────────┐  ┌────────────────────────────┐   │
│  │  Presence   │  │  Auth (SSO+JWT)            │   │
│  │  Position   │  │  HR Data Sync              │   │
│  │  Chat relay │  │  Room Booking              │   │
│  │  AI Handoff │  │  Task Manager              │   │
│  └─────────────┘  │  Achievement Sync          │   │
│                   └────────────────────────────┘   │
│              PostgreSQL + Redis                     │
└──────────────┬─────────────────────────────────────┘
               │
┌──────────────┴─────────────────────────────────────┐
│             EXTERNAL INTEGRATIONS                  │
│   SSO    │  HR System  │  ZPS Member  │  Claude API │
└────────────────────────────────────────────────────┘
```

---

# PART 2 — SYSTEM BLUEPRINT

## 2.1 World & Map System

### Bản đồ hiện tại
Office floor: **120×96 tiles** (~1920×1536 px ở tile size 16), bao gồm:
- 6 department zones: Engineering, Design, Product, HR, Data, Marketing
- 5 meeting rooms + Boardroom (tường vật lý, cửa có trigger)
- Pantry/Kitchen, Recreation Lounge, Reception Lobby
- **Tool Zones**: vùng đặc biệt do Senior/Lead sở hữu (xem 2.3)

### Camera & Navigation
| Action | Control |
|--------|---------|
| Di chuyển | WASD / Arrow Keys |
| Chạy | Shift + WASD |
| Camera pan | Mouse drag |
| Zoom | Scroll wheel (0.8×–4.0×) |
| Snap về player | F |
| Tương tác | E (khi đứng gần NPC/object) |

### World Layers
1. **Tilemap Layer**: floor, walls, furniture (static)
2. **Object Layer**: doors, interactable objects (Area2D triggers)
3. **Character Layer**: player + NPC sprites (sorted by Y)
4. **UI Layer**: chat bubbles, name tags, status indicators
5. **Overlay Layer**: event decorations, seasonal themes

### Seasonal & Event Decorations
World tự động nhận theme theo company calendar (Tết, anniversary, special event). HR/Admin trigger decoration từ backend — không cần redeploy client.

---

## 2.2 Character & Player System

### States của một Character
```
Online (real player)
  ↓ disconnect
Offline NPC mode (AI-driven)
  ↑ reconnect
Online
```

Khi player disconnect: nhân vật không biến mất. Chuyển sang NPC mode — vẫn đứng tại last position, AI trả lời thay. Transition phải mượt mà, không flash.

### Player Data Structure
```
PlayerData {
  employee_id: String
  display_name: String
  role_level: Enum(employee, senior, lead, admin)
  department: String
  avatar_config: AvatarConfig
  status: Enum(available, busy, away, offline)
  status_message: String
  desk_position: Vector2
  last_seen: DateTime
  achievement_badges: Array[Badge]  // synced từ ZPS Member
}
```

### Interaction Radius
- **Chat bubble**: hiện khi player nói, tồn tại 4 giây
- **Interaction zone**: Area2D r=64px quanh mỗi character — E để interact
- **Proximity voice indicator**: visual glow khi player ≤128px (future)

---

## 2.3 Role & Permission System

ZPS World có ba tầng role, được map trực tiếp từ HR level:

### Tầng 1 — Regular Employee (baseline)
Tất cả thành viên công ty. Có thể:
- Di chuyển tự do trong world
- Interact với NPC và player khác
- Truy cập tool thông qua interaction hoặc HUD shortcut
- Tham dự events và minigames
- Customize avatar trong phạm vi cosmetics đã unlock
- Xem profile của đồng nghiệp

### Tầng 2 — Senior / Lead (ba lớp chồng nhau)

**Layer A — Super NPC**
> *Khi offline, nhân vật họ ở lại trong world như NPC thông minh hơn.*

- AI context được nạp từ tool documentation, team knowledge base, FAQ
- Avatar có visual indicator đặc biệt (halo, name color khác)
- Câu trả lời của NPC này có độ chính xác cao hơn NPC thường
- Khi online trở lại: seamless takeover, NPC nhường quyền điều khiển

**Layer B — Tool Owner**
> *Mỗi Senior/Lead sở hữu một Tool Zone trong world.*

- Zone hiển thị tên họ trên minimap ("AI Lab — @sangvk", "Design Studio — @linh.vu")
- Họ là người duy nhất có thể cấu hình tool trong zone đó (thêm FAQ, cập nhật knowledge base)
- Zone có signage riêng, aesthetic riêng
- Nếu họ không còn ở công ty: zone chuyển về "Unowned" state

**Layer C — Guild Master**
> *Trong phạm vi team của mình, họ có quyền admin giới hạn.*

- Tạo/xóa team-scoped events
- Pin announcement lên team zone board
- Giao task trực tiếp từ trong game (tích hợp task manager)
- Xem dashboard presence của team members
- Không có quyền thay đổi world layout hay global settings

### Tầng 3 — Admin
- Tạo company-wide events
- Manage seasonal decorations
- Xem analytics (presence, tool usage, NPC query volume)
- Full access tất cả zones
- Reset/override bất kỳ player state nào

### Permission Matrix

| Action | Employee | Senior/Lead | Admin |
|--------|----------|-------------|-------|
| Di chuyển & interact | ✅ | ✅ | ✅ |
| Truy cập tool | ✅ (self-service own data) | ✅ (configure zone + own data) | ✅ (all) |
| Tạo event | ❌ | ✅ (team-scoped) | ✅ (global) |
| Pin announcement | ❌ | ✅ (team zone) | ✅ (world) |
| Configure tool zone | ❌ | ✅ (own zone) | ✅ (all) |
| Super NPC mode | ❌ | ✅ | ✅ |
| Xem presence analytics | ❌ | ✅ (team) | ✅ (all) |

---

## 2.4 Tool Integration Hub

### Nguyên tắc tích hợp

**Game layer là optional overlay.** Mỗi tool có ba cách truy cập, hoạt động độc lập với nhau:

| Access Path | Dành cho ai |
|-------------|-------------|
| **In-world Location** — đi vào phòng/zone trong bản đồ | Người dùng game layer |
| **HUD Shortcut** — keystroke mở panel overlay từ bất kỳ đâu trong game | Người dùng game layer, power user |
| **Direct URL / Standalone Tab** — truy cập tool trực tiếp không qua game | Người không dùng game interface |

Không có feature nào bị lock sau game world. Nếu công ty deploy workspace với nhiều tab, ZPS World là một tab, HR Tool là tab khác, Task Manager là tab khác — hoàn toàn độc lập. Game layer chỉ là *cách tiếp cận thêm*, không thay thế.

**Workspace Embed:** Sau khi export HTML5/WASM, ZPS World được nhúng vào workspace chính của công ty như một iframe tab. Backend API dùng chung với các tool khác — không duplicate data, không cần đăng nhập lần hai (same SSO session).

### Tool Registry

| Tool | In-world Location | HUD Key | Owner Layer |
|------|------------------|---------|-------------|
| **AI Agents** | AI Lab zone | `Tab` | Senior AI Lead |
| **HR Tool** | HR Department zone | `H` (Workspace Panel) | HR Admin |
| **Task Manager** | Board Room / team zones | `T` | Team Lead |
| **Room Booking** | Meeting room doors | `E` (khi đứng ở cửa) | Admin |
| **Announcements** | Reception board | passive | Admin / Lead |
| **Course/LMS** | Lecture Hall | `L` | HR Admin |
| **Avatar Generator** | Locker Room / avatar station | `Shift+A` | Self |
| **Profile View** | Bấm vào bất kỳ player/NPC | click | — |

### Tool Panel Architecture
Mỗi tool panel là một Godot `Control` node (CanvasLayer), load on-demand:
- Giao tiếp với backend qua REST API
- State persist trong session (không reset khi đóng panel)
- Keyboard shortcut toggle (open/close)
- Có thể embed WebView cho tool phức tạp (fallback)

### AI Agent Integration
Đã có từ Sprint 0 (Claude API + mock mode). Expand để:
- Mỗi Super NPC có system prompt riêng (do Tool Owner cấu hình)
- Global AI context bao gồm: org chart, room status, current events
- ConversationMemory persist theo session, không leak giữa players
- Rate limiting: max 20 queries/player/giờ để kiểm soát cost

---

## 2.5 Social & Communication Layer

### Proximity Chat
- Chat bubble hiện trên đầu avatar, tồn tại 4 giây
- Chỉ visible với players trong radius 256px (proximity feel)
- Chat log panel lưu toàn bộ (kể cả ngoài radius)

### Direct Message
- DM panel accessible từ HUD hoặc click vào player
- Tin nhắn persist qua sessions (stored in backend)
- Notification badge trên avatar của player được DM

### Emote System
Shortcut quick-emote dạng radial menu (`Q` key):
- Wave 👋, Thumbs up 👍, Clap 👏, Question ❓, Think 🤔, Party 🎉

### Presence & Status
Player có thể set:
- `Available` (green) — có thể interact
- `Busy` (yellow) — đang họp/làm việc
- `Away` (gray) — tự động sau 10 phút không activity
- `Offline` (dark) — chuyển NPC mode

Status message tùy chỉnh: "Đang review PR", "Họp đến 3h", v.v.

---

## 2.6 Events & Minigames System

### Event Types

| Type | Ai tạo | Scope | Ví dụ |
|------|--------|-------|-------|
| **Official** | HR / Admin | Company-wide | Town hall, onboarding, company anniversary |
| **Team Official** | Senior/Lead | Team-scoped | Sprint review, team retrospective, team lunch |
| **Non-official** | Senior/Lead (opt-in) | Open invite | Game session, trivia night, movie night |

Employee thường không được tạo event — giữ quality control. Senior/Lead có thể tạo Non-official event sau khi được enable bởi Admin.

### Event Lifecycle
```
Lead tạo event → chọn location (zone/room) → set time + description
→ System thông báo all relevant players (HUD toast + optional email)
→ Ngày event: world decoration activate, NPC hướng dẫn đến location
→ Event kết thúc: attendance synced với ZPS Member system
```

### Minigames
Minigame là game nhỏ chạy trong Godot, không external dependency. Được spawn bởi Senior/Lead trong zone của họ hoặc tại Recreation Lounge.

Phase 1 minigames (Sprint 5):
- **ZPS Trivia**: câu hỏi về công ty, lịch sử, sản phẩm
- **Word Scramble**: unscramble từ liên quan ZPS/tech
- **Reaction Quiz**: ai nhấn nhanh nhất thắng

Future minigames có thể được đóng góp bởi Senior/Lead (Minigame SDK — Phase 6+).

### Lecture Hall
Phòng đặc biệt hỗ trợ event dạng presentation:
- NPC/Player presenter đứng ở podium
- Audience seating
- Slide display system (chia sẻ URL → hiện trong-world)
- Q&A mode (raise hand emoji)

---

## 2.7 Avatar & Profile System

### Avatar Layers (từ dưới lên)
```
[Body shape] → [Skin color] → [Outfit] → [Hair] → [Accessory] → [Expression badge]
```

Mỗi layer có slot riêng. Render theo thứ tự layer để hỗ trợ transparency đúng.

### Avatar Generator Tool
- Tool riêng tích hợp trong game (Shift+A → Avatar Customizer)
- Tuân theo **ZPS Standard**: color palette, proportions, style guide định sẵn
- Output: config JSON → render thành sprite tại runtime (programmatic, không cần pre-render)
- Hỗ trợ export avatar as PNG (cho Slack, email signature)

### Cosmetic Unlock — ZPS Member Sync
Không có grinding. Cosmetics unlock theo achievement từ ZPS Member system:

| ZPS Member Achievement | Cosmetic Unlock |
|------------------------|-----------------|
| 1 Year Anniversary | Special outfit frame + badge |
| Top Performer Q | Gold name glow |
| Event Attendance ×10 | Party hat accessory |
| Training Completion | Graduation cap |
| Onboarding Complete | "Newbie" → "Member" badge |
| ... | ... |

Sync là **one-way pull**: ZPS World poll ZPS Member API, không push ngược lại.

### Player Profile Card
Click vào bất kỳ avatar nào → Profile card popup:
- Display name + job title + department
- Current status + status message
- Achievement badge display (top 3)
- Quick actions: DM, View desk, View tasks (Lead only)
- Online/Offline indicator
- Nếu NPC mode: hiển thị "AI-assisted — [tên] đang offline"

### Desk Customization
Mỗi player có desk trong world. Nhấn `D` khi đứng ở desk:
- Item placement grid (4×3)
- Items: plants, monitors, figures, photos — unlock qua achievements
- Layout persist giữa sessions

---

## 2.8 Technical Architecture

### Client Stack
```
Godot 4.x (GDScript)
├── Autoloads (Singletons)
│   ├── GameManager.gd     — global state, event bus, employee registry
│   ├── PlayerData.gd      — current player data, avatar config
│   ├── AIAgent.gd         — Claude API + mock mode
│   ├── AIConfig.gd        — API keys, model selection
│   └── ConversationMemory.gd — per-session conversation context
├── World
│   ├── Office.gd          — TileMap, room zones, collision
│   └── CameraController.gd — drag-pan, zoom, snap
├── Player
│   └── Player.gd          — movement, interaction, visual build
├── NPC
│   └── Employee.gd        — NPC state machine, AI handoff
└── UI
    ├── HUD.gd             — hotbar, notifications, status
    ├── InteractionDialog.gd — chat + AI reply panel
    ├── AvatarCustomizer.gd — layered avatar editor
    └── WorkspacePanel.gd  — tool hub shortcut panel
```

### Backend Stack
```
Node.js WebSocket Server (ws library)
├── Tick rate: 50ms (20Hz position updates)
├── Rooms: per-zone namespacing
├── Events: join, leave, move, chat, emote, status_change
└── AI handoff: player_disconnect → npc_activate

NestJS REST API
├── Auth: SSO → JWT (access + refresh)
├── Employees: CRUD, role management
├── Rooms: booking, availability
├── Tasks: create, assign, status (integration layer)
├── Events: CRUD, attendance tracking
├── Achievements: ZPS Member sync (poll interval: 1h)
└── Analytics: presence, tool usage, NPC queries

Database: PostgreSQL
├── employees, roles, departments
├── room_bookings
├── tasks, task_assignments
├── events, event_attendance
├── chat_messages (DM)
└── cosmetic_unlocks

Cache: Redis
├── player_presence (TTL: 30s)
├── session_data
└── npc_context_cache (TTL: 1h)
```

### Build Targets
| Target | Export | Serve | Use case |
|--------|--------|-------|---------|
| **Web (primary)** | HTML5/WASM | Intranet nginx | All employees, daily use |
| **Workspace Tab (embed)** | HTML5/WASM (same build) | iframe trong workspace | Nhúng vào workspace chính, SSO session chia sẻ |
| **Desktop (optional)** | Windows/macOS .exe | Direct download | Senior/Lead hosting tools |

### Standalone Tool Access
Mỗi tool tích hợp trong ZPS World đều có route độc lập trên backend. Ví dụ:
- `workspace.zps.vn/hr` → HR Tool trực tiếp (không qua game)
- `workspace.zps.vn/tasks` → Task Manager trực tiếp
- `workspace.zps.vn/ai` → AI Agent trực tiếp
- `workspace.zps.vn/world` → ZPS World (game tab)

Người dùng có thể bookmark bất kỳ tool nào và dùng như web app bình thường.

### Multiplayer Flow
```
Player opens browser → loads WASM → GameManager init
→ REST /auth (SSO token → JWT)
→ WS connect → send player_join {id, position, avatar}
→ Server broadcasts to room → other clients spawn remote player
→ Position loop: client sends move every 50ms
→ Other clients lerp to predicted position
→ Player closes tab → server broadcasts player_leave → others show NPC mode
```

---

## 2.9 Security & Auth

### Authentication Flow
```
Employee → Company SSO (SAML/OAuth2)
→ Backend validates SSO token
→ Issues JWT (access: 1h, refresh: 7d)
→ Godot client stores JWT in memory (không persist to disk)
→ All API calls: Authorization: Bearer <JWT>
→ WebSocket: JWT passed in connection handshake
```

### Authorization Rules
- **Role-based**: permissions gắn với HR level (employee/senior/lead/admin)
- **Scope-based**: Lead chỉ có quyền trong team/zone của mình
- **Rate limiting**: AI queries (20/player/h), API calls (100/player/min)
- **Data isolation**: player không thể đọc DM của người khác, không thể modify player data của người khác

### Sensitive Data
- Không lưu bất kỳ credential nào trong Godot client
- HR data chỉ visible ở mức cần thiết (attendance của bản thân, không thấy của người khác trừ Manager)
- AI conversation logs encrypted at rest

---

# PART 3 — ROADMAP

## 3.1 MVP Definition

MVP là phiên bản đủ để launch nội bộ và có giá trị thực ngay từ ngày đầu.

**Must Have (MVP)**
- [ ] Web-accessible world (Godot WASM served on intranet)
- [ ] SSO authentication
- [ ] Real multiplayer: thấy đồng nghiệp di chuyển realtime
- [ ] Player profiles + avatar (ZPS standard)
- [ ] AI NPC mode khi player offline
- [ ] Workspace Panel: HR leave request + task view
- [ ] Room booking qua meeting room door
- [ ] Senior/Lead Super NPC mode (richer AI context)
- [ ] Basic chat (proximity + DM)

**Should Have (Launch + 1 sprint)**
- [ ] Senior/Lead Tool Zones trên bản đồ
- [ ] ZPS Member achievement sync → cosmetic unlocks
- [ ] Emote system
- [ ] Desk customization
- [ ] Event system (Admin tạo official events)

**Could Have (Sprint 5+)**
- [ ] Minigames
- [ ] Lecture Hall mode
- [ ] Non-official events (Lead-created)
- [ ] Seasonal world decorations
- [ ] Avatar PNG export

**Won't Have (v1)**
- 3D world
- Mobile app
- External player (non-ZPS)
- Custom minigame SDK

---

## 3.2 Phase Plan

| Sprint | Duration | Goal | Key Deliverables |
|--------|----------|------|-----------------|
| **S0 — Foundation** ✅ | Week 1-2 | Working prototype | World, player movement, AI agent, basic UI |
| **S1 — Assets** | Week 3-4 | Visual polish | Real pixel art sprites, tileset, furniture |
| **S2 — Multiplayer** | Week 5-7 | Real presence | WebSocket server, position sync, online roster |
| **S3 — Backend + Tools** | Week 8-10 | **MVP launch** | SSO auth, HR integration, task view, room booking |
| **S4 — Avatar + Profile** | Week 11-12 | Identity depth | Full avatar system, ZPS Member sync, desk deco |
| **S5 — Events + Games** | Week 13-15 | Engagement | Event system, minigames, lecture hall |
| **S6 — 3D Exploration** | TBD | Future | Godot 3D or Three.js, VRM avatar |

### Sprint 2 Details — Multiplayer

Critical architecture decision: **Node.js `ws` server** (không dùng Godot MultiplayerAPI vì web export có limitations).

```
Client (Godot WASM) ←→ Node.js WS Server ←→ All Clients
```

Position updates: 50ms tick, lerp on receive. Chat: relay ngay lập tức.

### Sprint 3 Details — Backend + MVP Launch

NestJS API cần hoàn thành:
- SSO integration (phụ thuộc công ty đang dùng gì — cần confirm với IT)
- `/employees` sync từ HR system
- `/bookings` room booking
- `/tasks` read-only view từ task system (Jira/equivalent)
- `/auth` JWT flow

### Sprint 4 Details — Avatar Depth

Avatar Generator Tool cần:
- ZPS color palette & style guide (cần Design team sign-off)
- Layered sprite system: 7 layers, 16-direction sprite sheets
- ZPS Member API endpoint (cần confirm với ZPS Member team)

---

## 3.3 Future Scope

### ZPS World 3D (Sprint 6+)
Chuyển từ top-down 2D sang 3D không phải rewrite — Godot 4 hỗ trợ cả hai. Hai hướng:

| Option | Engine | Pros | Cons |
|--------|--------|------|------|
| **Godot 3D** | Godot 4 | Cùng autoloads, cùng GDScript, same backend | Cần học 3D workflow |
| **Three.js Web** | Browser-native | Không cần install, dễ embed iframe | Tách rời khỏi Godot codebase |
| **VRM Avatar** | Godot plugin | Standard format, interoperable | Plugin maturity thấp |

Khuyến nghị: Godot 3D sau khi 2D world stable.

### Mobile Companion App
Companion app nhẹ (không cần full world render) cho:
- Xem presence đồng nghiệp
- Nhận notification event
- DM
- Quick status update

### Minigame SDK
Sau Sprint 5, mở SDK để Senior/Lead tự đóng góp minigame mới dưới dạng Godot plugin/addon. Có review process trước khi deploy vào world chính.

### External Integrations (Phase 2+)
- Slack integration: status sync hai chiều
- Google Calendar: meeting room tự block khi có lịch họp
- Performance review system: thêm achievement source mới

---

*Document này là living document — cập nhật sau mỗi sprint khi có thay đổi thiết kế quan trọng.*
