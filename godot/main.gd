extends Node2D

const ARENA_SIZE := Vector2(1280, 720)
const MAX_WEAPONS := 5
const WEAPONS := {
    "VOID BLADE": {"family": "MELEE", "color": Color("ed725c"), "cooldown": 0.8},
    "STAR BOLT": {"family": "RANGED", "color": Color("edc968"), "cooldown": 0.32},
    "GRAVITY NOVA": {"family": "MELEE", "color": Color("63d1c2"), "cooldown": 1.5},
    "SOUL CHAIN": {"family": "MELEE", "color": Color("a98cff"), "cooldown": 1.1},
    "ROYAL METEOR": {"family": "RANGED", "color": Color("ff9b52"), "cooldown": 2.2}
}
const MONSTERS := {
    "WISP": {"color": Color("63d1c2"), "radius": 13.0, "health": 30.0, "speed": 55.0},
    "BRUTE": {"color": Color("ed725c"), "radius": 26.0, "health": 130.0, "speed": 25.0},
    "CHARGER": {"color": Color("edc968"), "radius": 16.0, "health": 55.0, "speed": 105.0},
    "ORACLE": {"color": Color("9fd6ff"), "radius": 19.0, "health": 70.0, "speed": 30.0}
}

var player := {"position": Vector2(640, 360), "health": 85.0, "speed": 240.0}
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var relics: Array[Dictionary] = []
var equipped: Array[String] = []
var weapon_cooldowns := {}
var spawn_timer := 0.0
var elapsed := 0.0
var essence := 0
var status := "UNARMED - COLLECT A RELIC"

func _ready() -> void:
    relics.append({"position": player.position + Vector2(100, 0), "weapon": "VOID BLADE", "family": "MELEE"})
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    var movement := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y += 1
    if movement.length() > 0: player.position += movement.normalized() * player.speed * delta
    player.position.x = clamp(player.position.x, 35.0, ARENA_SIZE.x - 35.0)
    player.position.y = clamp(player.position.y, 35.0, ARENA_SIZE.y - 35.0)
    spawn_timer -= delta
    if spawn_timer <= 0.0:
        spawn_enemy()
        spawn_timer = 0.9
    collect_relics()
    auto_cast(delta)
    update_projectiles(delta)
    update_enemies(delta)
    queue_redraw()

func spawn_enemy() -> void:
    var side := randi() % 4
    var position := Vector2.ZERO
    if side == 0: position = Vector2(-30, randf_range(0, ARENA_SIZE.y))
    elif side == 1: position = Vector2(ARENA_SIZE.x + 30, randf_range(0, ARENA_SIZE.y))
    elif side == 2: position = Vector2(randf_range(0, ARENA_SIZE.x), -30)
    else: position = Vector2(randf_range(0, ARENA_SIZE.x), ARENA_SIZE.y + 30)
    var type: String = MONSTERS.keys().pick_random()
    var data: Dictionary = MONSTERS[type]
    enemies.append({"position": position, "type": type, "radius": data.radius, "health": data.health, "speed": data.speed})

func nearest_enemy() -> Dictionary:
    var nearest: Dictionary = enemies[0]
    for enemy in enemies:
        if enemy.position.distance_to(player.position) < nearest.position.distance_to(player.position): nearest = enemy
    return nearest

func auto_cast(delta: float) -> void:
    if enemies.is_empty() or equipped.is_empty(): return
    var target := nearest_enemy()
    for weapon in equipped:
        weapon_cooldowns[weapon] = max(0.0, weapon_cooldowns.get(weapon, 0.0) - delta)
        if weapon_cooldowns[weapon] <= 0.0:
            weapon_cooldowns[weapon] = WEAPONS[weapon].cooldown
            if weapon == "VOID BLADE" and target.position.distance_to(player.position) < 115.0:
                target.health -= 38.0
                status = "VOID BLADE SWING"
            elif weapon == "GRAVITY NOVA":
                for enemy in enemies:
                    if enemy.position.distance_to(player.position) < 145.0: enemy.health -= 28.0
            elif weapon == "SOUL CHAIN": target.health -= 31.0
            elif weapon == "ROYAL METEOR": projectiles.append({"position": target.position, "velocity": Vector2.ZERO, "damage": 70.0, "life": 0.5, "radius": 48.0, "impact": true, "color": WEAPONS[weapon].color})
            else: projectiles.append({"position": player.position, "velocity": player.position.direction_to(target.position) * 560.0, "damage": 24.0, "life": 1.5, "radius": 7.0, "impact": false, "color": WEAPONS[weapon].color})

func collect_relics() -> void:
    for relic in relics.duplicate():
        if player.position.distance_to(relic.position) < 42.0:
            if not equipped.has(relic.weapon) and equipped.size() < MAX_WEAPONS:
                equipped.append(relic.weapon)
                weapon_cooldowns[relic.weapon] = 0.0
                status = "%s CLAIMED / %s PATH" % [relic.weapon, relic.family]
            relics.erase(relic)

func update_projectiles(delta: float) -> void:
    for projectile in projectiles.duplicate():
        projectile.life -= delta
        if projectile.impact:
            for enemy in enemies:
                if enemy.position.distance_to(projectile.position) < projectile.radius: enemy.health -= projectile.damage * delta * 3.0
        else:
            projectile.position += projectile.velocity * delta
            for enemy in enemies:
                if enemy.position.distance_to(projectile.position) < enemy.radius + projectile.radius:
                    enemy.health -= projectile.damage
                    projectile.life = 0.0
        if projectile.life <= 0.0: projectiles.erase(projectile)

func update_enemies(delta: float) -> void:
    for enemy in enemies.duplicate():
        enemy.position += enemy.position.direction_to(player.position) * enemy.speed * delta
        if enemy.position.distance_to(player.position) < enemy.radius + 17.0: player.health -= 10.0 * delta
        if enemy.health <= 0.0:
            essence += 10
            enemies.erase(enemy)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("101a2c"))
    for x in range(0, int(ARENA_SIZE.x), 48): draw_line(Vector2(x, 0), Vector2(x, ARENA_SIZE.y), Color(1, 1, 1, 0.04))
    for y in range(0, int(ARENA_SIZE.y), 48): draw_line(Vector2(0, y), Vector2(ARENA_SIZE.x, y), Color(1, 1, 1, 0.04))
    for relic in relics:
        var data: Dictionary = WEAPONS[relic.weapon]
        draw_circle(relic.position, 35.0 + sin(elapsed * 4.0) * 5.0, Color(data.color, 0.12))
        var diamond := PackedVector2Array([relic.position + Vector2(0, -22), relic.position + Vector2(22, 0), relic.position + Vector2(0, 22), relic.position + Vector2(-22, 0)])
        draw_colored_polygon(diamond, Color("18253a"))
        draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), data.color, 3.0)
    for projectile in projectiles: draw_circle(projectile.position, projectile.radius, projectile.color)
    for enemy in enemies:
        var data: Dictionary = MONSTERS[enemy.type]
        draw_circle(enemy.position + Vector2(0, enemy.radius + 7), enemy.radius * .45, Color(0, 0, 0, .4))
        draw_circle(enemy.position, enemy.radius, Color("0b111d"))
        draw_arc(enemy.position, enemy.radius, 0, TAU, 16, data.color, 3.0)
        draw_circle(enemy.position + Vector2(5, -4), 3, data.color)
        draw_circle(enemy.position + Vector2(5, 5), 3, data.color)
    draw_circle(player.position + Vector2(0, 25), 30, Color(0, 0, 0, .45))
    draw_circle(player.position, 20, Color("aebbb2"))
    draw_arc(player.position, 20, 0, TAU, 16, Color("edc968"), 3.0)
    var crown := PackedVector2Array([player.position + Vector2(-12, -21), player.position + Vector2(0, -45), player.position + Vector2(12, -21), player.position + Vector2(0, -30)])
    draw_colored_polygon(crown, Color("edc968"))
    draw_line(player.position + Vector2(19, 5), player.position + Vector2(43, 28), Color("aebbb2"), 5.0)
