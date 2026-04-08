# NPC AI Behavior System — LimboAI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thay thế hệ thống wander thủ công trong `Employee.gd` bằng LimboAI Behavior Tree, cho NPC có 4 trạng thái rõ ràng: **Idle → Wander → React to Player → Talking**.

**Architecture:** Mỗi Employee được gắn một `BTPlayer` node chạy behavior tree dùng chung (`employee_behavior`). `Blackboard` lưu trạng thái riêng mỗi NPC (`zone_rect`, `wander_target`, `idle_timer`). Custom `BTAction`/`BTCondition` scripts đọc/ghi blackboard và gọi `move_and_slide()` trực tiếp trên agent. `AIAgent` autoload vẫn giữ nguyên — LimboAI chỉ điều khiển di chuyển/animation, AIAgent lo conversation.

**Tech Stack:** GDScript, LimboAI v1.7.0 GDExtension (BTPlayer, BehaviorTree, Blackboard, BTAction, BTCondition, BTSequence, BTSelector), Godot 4.6

---

## Behavior Tree Design

```
BTSelector (root — chạy từ trên xuống, dừng ở branch đầu tiên RUNNING)
│
├── [P1] BTSequence "Talking"          ← ưu tiên cao nhất, block tất cả
│       ├── BTIsTalking (condition)
│       └── BTIdleInPlace (action)     ← đứng yên mãi cho đến khi is_talking = false
│
├── [P2] BTSequence "React"            ← player lại gần → quay mặt + show hint
│       ├── BTIsPlayerNearby (condition)
│       └── BTFacePlayer (action)
│
└── [P3] BTSequence "Wander"           ← hành vi mặc định, loop liên tục
        ├── BTIdleInPlace (action)     ← đứng 2–5s (random)
        ├── BTPickWanderTarget (action) ← chọn điểm random trong zone_rect
        └── BTWalkToTarget (action)    ← đi đến điểm đó rồi SUCCESS
```

## Blackboard Variables

| Key | Type | Mô tả |
|-----|------|-------|
| `zone_rect` | Rect2 | Vùng NPC được phép đi, set từ Campus.gd |
| `wander_target` | Vector2 | Điểm đến hiện tại |
| `idle_remaining` | float | Bộ đếm ngược thời gian idle |

---

## File Map

**Tạo mới:**
- `scripts/ai/conditions/BTIsTalking.gd`
- `scripts/ai/conditions/BTIsPlayerNearby.gd`
- `scripts/ai/actions/BTIdleInPlace.gd`
- `scripts/ai/actions/BTPickWanderTarget.gd`
- `scripts/ai/actions/BTWalkToTarget.gd`
- `scripts/ai/actions/BTFacePlayer.gd`

**Sửa:**
- `scripts/npc/Employee.gd` — xóa wander thủ công, thêm `_setup_behavior_tree()`

---

## Task 1: BTIsTalking — Condition

**Files:**
- Create: `scripts/ai/conditions/BTIsTalking.gd`

- [ ] **Step 1: Tạo file condition**

```gdscript
## BTIsTalking.gd
## Trả về SUCCESS nếu NPC đang bị talk to, FAILURE nếu không.
## Dùng ở P1 của behavior tree để block toàn bộ movement.
extends BTCondition

func _tick(_delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE
	return SUCCESS if emp.is_being_talked_to else FAILURE
```

- [ ] **Step 2: Verify file tồn tại và không có lỗi syntax**

Mở Godot Editor → Script tab → mở file, kiểm tra không có error đỏ ở bottom panel.

- [ ] **Step 3: Commit**

```bash
git add scripts/ai/conditions/BTIsTalking.gd
git commit -m "feat(ai): add BTIsTalking condition for LimboAI"
```

---

## Task 2: BTIsPlayerNearby — Condition

**Files:**
- Create: `scripts/ai/conditions/BTIsPlayerNearby.gd`

- [ ] **Step 1: Tạo file condition**

```gdscript
## BTIsPlayerNearby.gd
## SUCCESS nếu player trong vòng DETECT_RANGE pixels.
## NPC sẽ quay mặt nhìn player khi condition này true.
extends BTCondition

const DETECT_RANGE := 60.0

func _tick(_delta: float) -> Status:
	var player := agent.get_tree().get_first_node_in_group("player")
	if player == null:
		return FAILURE
	var dist: float = agent.global_position.distance_to(player.global_position)
	return SUCCESS if dist <= DETECT_RANGE else FAILURE
```

- [ ] **Step 2: Verify không lỗi syntax trong Editor**

- [ ] **Step 3: Commit**

```bash
git add scripts/ai/conditions/BTIsPlayerNearby.gd
git commit -m "feat(ai): add BTIsPlayerNearby condition (60px detection range)"
```

---

## Task 3: BTIdleInPlace — Action

NPC đứng yên trong N giây. Dùng ở 2 nơi: Talking branch (đợi vô thời hạn) và Wander branch (nghỉ 2–5s trước khi đi).

**Files:**
- Create: `scripts/ai/actions/BTIdleInPlace.gd`

- [ ] **Step 1: Tạo file action**

```gdscript
## BTIdleInPlace.gd
## RUNNING trong khi đếm ngược idle_remaining.
## wait_min / wait_max: khoảng thời gian random (giây).
## wait_min = wait_max = 0.0 → đợi vô hạn (dùng cho Talking branch).
extends BTAction

@export var wait_min: float = 2.0
@export var wait_max: float = 5.0

func _enter() -> void:
	agent.velocity = Vector2.ZERO
	if wait_min <= 0.0 and wait_max <= 0.0:
		# Vô hạn — Talking branch tự thoát khi BTIsTalking trả FAILURE
		blackboard.set_var("idle_remaining", INF)
	else:
		var t := randf_range(wait_min, wait_max)
		blackboard.set_var("idle_remaining", t)

func _tick(delta: float) -> Status:
	var remaining: float = blackboard.get_var("idle_remaining", 0.0)
	if remaining == INF:
		return RUNNING  # Talking branch: đợi mãi
	remaining -= delta
	blackboard.set_var("idle_remaining", remaining)
	if remaining <= 0.0:
		return SUCCESS
	return RUNNING
```

- [ ] **Step 2: Verify không lỗi**

- [ ] **Step 3: Commit**

```bash
git add scripts/ai/actions/BTIdleInPlace.gd
git commit -m "feat(ai): add BTIdleInPlace action with configurable wait range"
```

---

## Task 4: BTPickWanderTarget — Action

Chọn điểm ngẫu nhiên trong `zone_rect` và lưu vào blackboard.

**Files:**
- Create: `scripts/ai/actions/BTPickWanderTarget.gd`

- [ ] **Step 1: Tạo file action**

```gdscript
## BTPickWanderTarget.gd
## Chọn random point trong zone_rect của NPC.
## Trả SUCCESS ngay lập tức sau khi set wander_target.
extends BTAction

const MARGIN := 12.0  # padding khỏi edge của zone

func _tick(_delta: float) -> Status:
	var zone: Rect2 = blackboard.get_var("zone_rect", Rect2())
	if not zone.has_area():
		# Không có zone → wander quanh vị trí hiện tại
		var angle := randf() * TAU
		var dist := randf_range(20.0, 50.0)
		blackboard.set_var("wander_target",
			agent.position + Vector2(cos(angle), sin(angle)) * dist)
		return SUCCESS

	var target := Vector2(
		randf_range(zone.position.x + MARGIN, zone.end.x - MARGIN),
		randf_range(zone.position.y + MARGIN, zone.end.y - MARGIN)
	)
	blackboard.set_var("wander_target", target)
	return SUCCESS
```

- [ ] **Step 2: Verify không lỗi**

- [ ] **Step 3: Commit**

```bash
git add scripts/ai/actions/BTPickWanderTarget.gd
git commit -m "feat(ai): add BTPickWanderTarget action with zone boundary clamping"
```

---

## Task 5: BTWalkToTarget — Action

Di chuyển NPC đến `wander_target`. Cập nhật animation facing direction.

**Files:**
- Create: `scripts/ai/actions/BTWalkToTarget.gd`

- [ ] **Step 1: Tạo file action**

```gdscript
## BTWalkToTarget.gd
## Di chuyển NPC đến blackboard["wander_target"].
## RUNNING khi đang đi, SUCCESS khi đến nơi (< ARRIVE_DIST).
extends BTAction

const ARRIVE_DIST := 5.0

func _tick(delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE

	var target: Vector2 = blackboard.get_var("wander_target", emp.position)
	var dir := target - emp.position

	if dir.length() <= ARRIVE_DIST:
		emp.velocity = Vector2.ZERO
		return SUCCESS

	emp.velocity = dir.normalized() * emp.wander_speed
	emp.move_and_slide()
	emp._update_npc_facing(emp.velocity)
	return RUNNING
```

- [ ] **Step 2: Verify không lỗi**

- [ ] **Step 3: Commit**

```bash
git add scripts/ai/actions/BTWalkToTarget.gd
git commit -m "feat(ai): add BTWalkToTarget action with animation update"
```

---

## Task 6: BTFacePlayer — Action

NPC quay mặt về phía player và show interact hint. RUNNING cho đến khi player rời đi.

**Files:**
- Create: `scripts/ai/actions/BTFacePlayer.gd`

- [ ] **Step 1: Tạo file action**

```gdscript
## BTFacePlayer.gd
## NPC đứng yên, quay mặt về player, show interact hint.
## RUNNING khi player gần (BTIsPlayerNearby giữ branch này active).
## SUCCESS → không bao giờ trả, branch tự thoát khi condition fail.
extends BTAction

func _enter() -> void:
	var emp := agent as Employee
	if emp:
		emp.velocity = Vector2.ZERO
		emp.show_interact_hint()

func _exit() -> void:
	var emp := agent as Employee
	if emp:
		emp.hide_interact_hint()

func _tick(_delta: float) -> Status:
	var emp := agent as Employee
	if emp == null:
		return FAILURE

	var player := agent.get_tree().get_first_node_in_group("player")
	if player:
		var dir := player.global_position - emp.global_position
		# Cập nhật facing về phía player
		emp._update_npc_facing(dir)

	emp.velocity = Vector2.ZERO
	return RUNNING
```

- [ ] **Step 2: Verify không lỗi**

- [ ] **Step 3: Commit**

```bash
git add scripts/ai/actions/BTFacePlayer.gd
git commit -m "feat(ai): add BTFacePlayer action with hint show/hide on enter/exit"
```

---

## Task 7: Refactor Employee.gd — Wire up BTPlayer

Xóa wander thủ công, thêm `_setup_behavior_tree()`. `_update_npc_facing()` cần được đổi sang `public` (xóa underscore) để BTWalkToTarget và BTFacePlayer gọi được.

**Files:**
- Modify: `scripts/npc/Employee.gd`

- [ ] **Step 1: Thêm preload các action/condition scripts ở đầu file (sau `const _AR`)**

```gdscript
# ── LimboAI behavior scripts ──
const _BTIsTalking       = preload("res://scripts/ai/conditions/BTIsTalking.gd")
const _BTIsPlayerNearby  = preload("res://scripts/ai/conditions/BTIsPlayerNearby.gd")
const _BTIdleInPlace     = preload("res://scripts/ai/actions/BTIdleInPlace.gd")
const _BTPickWanderTarget = preload("res://scripts/ai/actions/BTPickWanderTarget.gd")
const _BTWalkToTarget    = preload("res://scripts/ai/actions/BTWalkToTarget.gd")
const _BTFacePlayer      = preload("res://scripts/ai/actions/BTFacePlayer.gd")
```

- [ ] **Step 2: Xóa các biến wander thủ công (dòng 33–35 hiện tại)**

Xóa 3 dòng này:
```gdscript
# ── Wander ──
var wander_target: Vector2 = Vector2.ZERO
var wander_timer:  float   = 0.0
const WANDER_INTERVAL = 5.0
```

Giữ nguyên `wander_range` và `wander_speed` vì BTWalkToTarget vẫn dùng `emp.wander_speed`.

- [ ] **Step 3: Đổi `_update_npc_facing` thành public**

Rename từ `_update_npc_facing` → `update_npc_facing` (xóa underscore) ở cả định nghĩa hàm và trong `_do_wander()`:

```gdscript
func update_npc_facing(vel: Vector2) -> void:   # ← đổi tên, xóa underscore
	if _anim_sprite == null:
		return
	# ... giữ nguyên body hàm
```

Đồng thời cập nhật BTWalkToTarget.gd và BTFacePlayer.gd: đổi `emp._update_npc_facing` → `emp.update_npc_facing`.

- [ ] **Step 4: Xóa `_physics_process` và `_do_wander` hoàn toàn (dòng 144–161 hiện tại)**

Xóa 2 hàm này:
```gdscript
func _physics_process(delta: float) -> void:
    ...
func _do_wander(delta: float) -> void:
    ...
```

- [ ] **Step 5: Thêm `_setup_behavior_tree()` và gọi nó trong `_ready()`**

Trong `_ready()`, thêm dòng sau `_load_employee_data()`:
```gdscript
_setup_behavior_tree()
```

Thêm hàm mới vào cuối file:
```gdscript
# ─────────────────────────────────────────────
# LimboAI Behavior Tree setup
# ─────────────────────────────────────────────
func _setup_behavior_tree() -> void:
	# ── Build tree structure ──
	var root := BTSelector.new()

	# P1: Talking branch — đứng yên khi đang chat
	var talking_seq := BTSequence.new()
	var idle_inf := _BTIdleInPlace.new()
	idle_inf.wait_min = 0.0
	idle_inf.wait_max = 0.0   # vô hạn
	talking_seq.add_child(_BTIsTalking.new())
	talking_seq.add_child(idle_inf)
	root.add_child(talking_seq)

	# P2: React branch — nhìn player khi gần
	var react_seq := BTSequence.new()
	react_seq.add_child(_BTIsPlayerNearby.new())
	react_seq.add_child(_BTFacePlayer.new())
	root.add_child(react_seq)

	# P3: Wander branch — idle rồi đi
	var wander_seq := BTSequence.new()
	var idle_wait := _BTIdleInPlace.new()
	idle_wait.wait_min = 2.0
	idle_wait.wait_max = 5.0
	wander_seq.add_child(idle_wait)
	wander_seq.add_child(_BTPickWanderTarget.new())
	wander_seq.add_child(_BTWalkToTarget.new())
	root.add_child(wander_seq)

	var bt := BehaviorTree.new()
	bt.root_task = root

	# ── Setup BTPlayer ──
	var bt_player := BTPlayer.new()
	bt_player.behavior_tree = bt
	bt_player.update_mode = BTPlayer.UpdateMode.PHYSICS
	add_child(bt_player)

	# ── Init blackboard ──
	bt_player.blackboard.set_var("zone_rect", zone_rect)
	bt_player.blackboard.set_var("wander_target", position)
	bt_player.blackboard.set_var("idle_remaining", 0.0)
```

- [ ] **Step 6: Commit**

```bash
git add scripts/npc/Employee.gd scripts/ai/actions/BTWalkToTarget.gd scripts/ai/actions/BTFacePlayer.gd
git commit -m "feat(npc): replace manual wander with LimboAI behavior tree"
```

---

## Task 8: Playtest & Verify

- [ ] **Step 1: Mở Godot Editor, chạy project (F5)**

Expected: Campus load bình thường, không có error đỏ trong Output panel.

- [ ] **Step 2: Verify NPC wander**

Quan sát NPC trong Main Office zone:
- NPC đứng 2–5 giây
- Đi đến điểm ngẫu nhiên trong zone
- Không ra ngoài boundary của zone
- Animation đúng hướng (north/south/west khi đi)

- [ ] **Step 3: Verify player detection**

Đi player lại gần NPC (trong 60px):
- NPC dừng lại
- NPC quay mặt về phía player
- Interact hint `[E/Click] Talk` hiện ra
- Khi player rời đi, hint biến mất, NPC resume wander

- [ ] **Step 4: Verify talking state**

Click hoặc nhấn E để interact với NPC:
- NPC hoàn toàn dừng di chuyển
- Sau khi đóng dialog (`finish_interaction()` gọi), NPC resume wander bình thường

- [ ] **Step 5: Verify multiple NPCs không ảnh hưởng nhau**

Quan sát nhiều NPC trong cùng zone — mỗi NPC có blackboard riêng, không share state.

- [ ] **Step 6: Commit final**

```bash
git add .
git commit -m "feat(ai): LimboAI NPC behavior system complete — wander/react/talk states"
```

---

## Ghi chú kỹ thuật

- **`BTPlayer.update_mode = PHYSICS`** — cần thiết vì `move_and_slide()` phải chạy trong physics frame
- **`_BTIdleInPlace` với `wait_min = wait_max = 0.0`** → `idle_remaining = INF` → block mãi. Branch này tự thoát khi `BTIsTalking` trả `FAILURE` (là khi `is_being_talked_to = false`)
- **`BTSelector`** chạy từ child đầu tiên: nếu trả `FAILURE`, thử child tiếp theo; nếu `RUNNING`, dừng tại đó
- **`wander_speed`** vẫn là `@export` trên Employee — có thể tweak per-NPC từ Campus.gd spawner
- **AIAgent không thay đổi** — `ask_ai_agent()` và `_on_ai_response()` vẫn nguyên, LimboAI không touch conversation flow
