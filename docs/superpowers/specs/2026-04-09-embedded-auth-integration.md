# ZPS World — Embedded Auth Integration Spec

| Field | Value |
|-------|-------|
| **Version** | 1.0 |
| **Date** | 2026-04-09 |
| **Status** | Draft — Pending Dev Review |
| **Related** | `2026-04-07-zps-world-master-design.md` — Section 2.9 |
| **Assignee** | Backend Team + Frontend/Godot Team |

---

## Bối cảnh

ZPS World được nhúng vào **company workspace** như một tab (iframe/WASM). Thay vì user tự đăng nhập qua form, game nhận identity từ workspace đang chạy và lấy danh sách nhân viên qua API chung.

**Trước (standalone):**
```
User → form login / SSO redirect → game JWT
```

**Sau (embedded):**
```
Workspace (đã login) → inject identity vào game → game exchange lấy JWT
```

---

## Tổng quan luồng đầy đủ

```
1. User mở workspace → đã đăng nhập (company SSO)
2. Workspace load tab ZPS World (iframe hoặc WASM embed)
3. Game init → lấy token từ parent (postMessage hoặc shared cookie)
4. Game gửi POST /auth/exchange { parent_token }
5. Backend validate token với company SSO
6. Backend upsert user profile trong game DB
7. Backend ký và trả game JWT (access + refresh)
8. Game dùng game JWT cho mọi request:
   - REST API: GET /employees, /rooms, /tasks, ...
   - WebSocket handshake: player_join event
9. Game render world với đúng PlayerData + NPC roster từ /employees
```

---

## Phần 1 — Truyền Identity từ Workspace vào Game

Chọn **một** trong ba cơ chế tùy theo cấu hình domain:

| Tình huống | Cơ chế | Ghi chú |
|---|---|---|
| Game và workspace cùng domain (`.zps.vn`) | Shared HttpOnly cookie | Đơn giản nhất, không cần code thêm phía game |
| Game là iframe từ domain khác | `window.postMessage` | Cần handshake protocol |
| Game nhận token qua URL khi load | Signed query param `?token=` | Ít bảo mật hơn, chỉ dùng nếu không còn lựa chọn |

### Cơ chế khuyến nghị: `postMessage` (iframe cross-origin)

**Phía Workspace (JS):**
```javascript
// Sau khi iframe ZPS World load xong
const gameFrame = document.getElementById('zps-world-frame');
const GAME_ORIGIN = 'https://zpsworld.zps.vn'; // origin của game — PHẢI chỉ định rõ

window.addEventListener('message', (event) => {
  // Chỉ xử lý message từ đúng origin của game
  if (event.origin !== GAME_ORIGIN) return;

  if (event.data?.type === 'REQUEST_AUTH_TOKEN') {
    // Lấy token từ company SSO session — KHÔNG dùng localStorage
    const token = getSessionToken(); // hàm này trả về token từ SSO session cookie/memory
    gameFrame.contentWindow.postMessage(
      { type: 'AUTH_TOKEN', token },
      GAME_ORIGIN // chỉ gửi đến đúng origin
    );
  }
});
```

**Phía Game (GDScript — Web export):**

Trong Godot 4 web export, dùng `JavaScriptBridge` để đăng ký listener nhận token từ parent window.
Xem chi tiết implementation trong `GameManager.gd` — phần Web Auth Bridge.

> **Lưu ý cho Godot dev**: Dùng `JavaScriptBridge.create_callback()` để nhận message từ JS một cách
> an toàn, thay vì truyền data thô qua string. Token phải được parse bằng `JSON.parse_string()`
> — không xử lý thông qua bất kỳ cơ chế execute code nào.

---

## Phần 2 — Backend: Endpoint `/auth/exchange`

### Spec

```
POST /auth/exchange
Content-Type: application/json

Body:
{
  "parent_token": "<access token từ company SSO>"
}

Response 200:
{
  "access_token": "<game JWT — expires 1h>",
  "refresh_token": "<game refresh token — expires 7d>",
  "user": {
    "employee_id": "string",
    "display_name": "string",
    "role_level": "employee | senior | lead | admin",
    "department": "string"
  }
}

Response 401:
{
  "error": "invalid_parent_token"
}
```

### Logic xử lý (NestJS)

```typescript
// auth.service.ts
async exchangeToken(parentToken: string): Promise<AuthResult> {
  // 1. Validate token với company SSO (gọi introspect endpoint)
  const ssoUser = await this.ssoService.introspect(parentToken);
  if (!ssoUser.active) {
    throw new UnauthorizedException('invalid_parent_token');
  }

  // 2. Map SSO data → game role
  const roleLevel = this.mapHrLevelToRole(ssoUser.job_level);

  // 3. Upsert user trong game DB (tạo nếu chưa có, cập nhật nếu đã có)
  const player = await this.playerRepository.upsert({
    employee_id: ssoUser.employee_id,
    display_name: ssoUser.display_name,
    department: ssoUser.department,
    role_level: roleLevel,
  });

  // 4. Ký game JWT
  return {
    access_token: this.jwtService.sign(
      { sub: player.employee_id, role: roleLevel },
      { expiresIn: '1h' }
    ),
    refresh_token: this.jwtService.sign(
      { sub: player.employee_id, type: 'refresh' },
      { expiresIn: '7d' }
    ),
    user: player,
  };
}
```

### Mapping HR Level → Game Role

| HR Level / Job Title (ví dụ) | Game `role_level` |
|---|---|
| Intern, Junior, Middle Engineer | `employee` |
| Senior Engineer, Senior Designer | `senior` |
| Tech Lead, Team Lead, Manager | `lead` |
| Director, Head of, C-level | `admin` |

> **Lưu ý:** Mapping này cần confirm với HR/IT để đúng với cấu trúc level thực tế của công ty.

---

## Phần 3 — Danh Sách Nhân Viên (`/employees`)

Game không nhận danh sách nhân viên từ parent. Thay vào đó, game **tự fetch** qua API sau khi có game JWT.

### Spec

```
GET /employees
Authorization: Bearer <game_jwt>

Response 200:
[
  {
    "employee_id": "string",
    "display_name": "string",
    "role_level": "employee | senior | lead | admin",
    "department": "string",
    "status": "online | offline | away | busy",
    "desk_position": { "x": 0, "y": 0 },
    "avatar_config": { ... }
  }
]
```

### Dùng để làm gì trong game

| Dữ liệu | Dùng cho |
|---|---|
| `status = online` | Render là real player (controlled) |
| `status = offline` | Render là NPC (AI-driven) |
| `role_level = senior / lead` | Thêm visual indicator (halo, name color) |
| `desk_position` | Vị trí spawn của NPC |
| `department` | Phân vào đúng zone trong world map |

---

## Phần 4 — Bảo mật

| Yêu cầu | Mô tả |
|---|---|
| `frame-ancestors` policy | Backend trả header `Content-Security-Policy: frame-ancestors https://workspace.zps.vn` — chỉ cho phép workspace chính nhúng game |
| Validate origin trong `postMessage` | Luôn kiểm tra `event.origin` trước khi xử lý message; từ chối nếu không khớp |
| Token không cache | Parent token chỉ dùng một lần để exchange, không lưu trong game |
| Game JWT không persist | Chỉ lưu trong memory — không `localStorage`, không `IndexedDB`, không disk |
| CORS | Backend chỉ accept request từ origin của workspace và game domain |
| Token expiry | Kiểm tra `exp` claim của parent token tại thời điểm exchange; reject nếu hết hạn |

---

## Phần 5 — Cần Confirm với IT / Backend Hiện Tại

Trước khi implement, cần làm rõ 4 câu hỏi sau:

- [ ] **Company SSO đang dùng giao thức gì?** (SAML 2.0, OAuth2, OpenID Connect, hay custom?)
- [ ] **Có endpoint introspect hoặc `/userinfo` không?** (để backend validate parent token)
- [ ] **HR system có API lấy danh sách nhân viên không?** Hay phải sync batch theo lịch?
- [ ] **Workspace embed cùng domain hay khác domain với game?** (quyết định cơ chế truyền token)

---

## Phần 6 — Checklist Implementation

### Backend Team
- [ ] Implement `POST /auth/exchange` endpoint
- [ ] Tích hợp SSO introspect / userinfo call
- [ ] Implement upsert logic cho player profile
- [ ] Mapping HR level → game role (confirm với HR)
- [ ] Đảm bảo `GET /employees` chỉ accept game JWT
- [ ] Cấu hình CORS và `Content-Security-Policy: frame-ancestors` header
- [ ] Cấu hình HR data sync (realtime API hoặc batch job)

### Godot / Frontend Team
- [ ] Implement `postMessage` handshake an toàn (validate origin)
- [ ] Parse token nhận về bằng `JSON.parse_string()` — không execute string
- [ ] Gọi `POST /auth/exchange` khi game init
- [ ] Lưu game JWT trong memory (không persist)
- [ ] Implement JWT refresh flow (tự động gọi lại trước khi hết hạn 1 phút)
- [ ] Dùng game JWT cho mọi REST call và WebSocket handshake
- [ ] Xử lý trường hợp exchange thất bại (hiển thị thông báo lỗi, không crash)

### QA / Integration
- [ ] Test luồng exchange với token hợp lệ → nhận game JWT
- [ ] Test luồng exchange với token hết hạn → 401 đúng format
- [ ] Test iframe không load được từ domain không được phép
- [ ] Test NPC render đúng với danh sách employee offline
- [ ] Test refresh token tự động khi access token sắp hết hạn
- [ ] Test message từ origin không hợp lệ bị bỏ qua
