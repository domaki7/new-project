extends Node2D

const ARENA_SIZE := Vector2(1280, 720)
const MAX_WEAPONS := 5
const WEAPONS := {
    "VOID BLADE": {"family": "MELEE", "color": Color("ed725c"), "cooldown": 0.8, "kind": "blade", "style": "blade", "damage_mult": 1.5, "reach": 100.0, "swing_arc": 1.15, "swing_time": 0.28, "orbit_speed": 0.35, "strength": "FAST / PRECISION", "weakness": "SHORT REACH"},
    "GRAVITY NOVA": {"family": "MELEE", "color": Color("63d1c2"), "cooldown": 1.5, "kind": "nova", "style": "nova", "damage_mult": 2.2, "reach": 126.0, "swing_arc": 1.8, "swing_time": 0.42, "orbit_speed": -0.18, "strength": "HEAVY / WIDE", "weakness": "SLOW STARTUP"},
    "SOUL CHAIN": {"family": "MELEE", "color": Color("a98cff"), "cooldown": 1.1, "kind": "chain", "style": "chain", "damage_mult": 1.3, "reach": 148.0, "swing_arc": 2.1, "swing_time": 0.32, "orbit_speed": 0.55, "strength": "LONG / POISON", "weakness": "LOWER BURST"},
    "STAR BOLT": {"family": "RANGED", "color": Color("edc968"), "cooldown": 0.32, "kind": "bolt"},
    "ROYAL METEOR": {"family": "RANGED", "color": Color("ff9b52"), "cooldown": 2.2, "kind": "meteor"},
    "FROST LANCE": {"family": "RANGED", "color": Color("9fd6ff"), "cooldown": 0.65, "kind": "frost"},
    "VENOM ORB": {"family": "RANGED", "color": Color("8ed66b"), "cooldown": 0.9, "kind": "venom"},
    "STORM SIGIL": {"family": "RANGED", "color": Color("d5b4ff"), "cooldown": 1.3, "kind": "storm"}
}
const UPGRADES := {
    "WAR BLESSING": {"family": "MELEE", "text": "+25% damage", "color": Color("ed725c")},
    "QUICKENED RITE": {"family": "RANGED", "text": "-18% cooldowns", "color": Color("edc968")},
    "IRON SOUL": {"family": "MELEE", "text": "+35 maximum vitality", "color": Color("9fd6ff")},
    "GRAVITY HAND": {"family": "RANGED", "text": "+20 pickup range", "color": Color("63d1c2")},
    "ARSENAL MASTERY": {"family": "MELEE", "text": "+18% all weapon damage", "color": Color("a98cff")},
    "EXECUTIONER RITE": {"family": "RANGED", "text": "15% critical chance", "color": Color("f2f0d0")},
    "BLOOD OF STARS": {"family": "MELEE", "text": "+2 vitality / second", "color": Color("ff9b52")},
    "CROWNWARD": {"family": "RANGED", "text": "+0.35s invulnerability", "color": Color("9fd6ff")}
}
const MONSTERS := {
    "WISP": {"color": Color("63d1c2"), "radius": 13.0, "health": 30.0, "speed": 55.0, "damage": 7.0, "essence": 10},
    "BRUTE": {"color": Color("ed725c"), "radius": 26.0, "health": 135.0, "speed": 25.0, "damage": 14.0, "essence": 28},
    "CHARGER": {"color": Color("edc968"), "radius": 16.0, "health": 55.0, "speed": 105.0, "damage": 11.0, "essence": 18},
    "SPLITTER": {"color": Color("a98cff"), "radius": 18.0, "health": 78.0, "speed": 42.0, "damage": 8.0, "essence": 20},
    "LEECH": {"color": Color("ff9b52"), "radius": 13.0, "health": 44.0, "speed": 68.0, "damage": 9.0, "essence": 16},
    "ORACLE": {"color": Color("9fd6ff"), "radius": 19.0, "health": 70.0, "speed": 30.0, "damage": 12.0, "essence": 24},
    "DREAD REGENT": {"color": Color("f2f0d0"), "radius": 35.0, "health": 560.0, "speed": 19.0, "damage": 28.0, "essence": 140}
}

var player := {"position": Vector2(640, 360), "health": 85.0, "max_health": 85.0, "speed": 235.0}
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var equipped: Array[String] = []
var weapon_ranks := {}
var weapon_cooldowns := {}
var weapon_swings := {}
var melee_impacts: Array[Dictionary] = []
var enemy_bursts: Array[Dictionary] = []
var unlocked_nodes := {}
var weapon_family := ""
var level := 1
var essence := 0
var wave := 1
var boss_spawned := false
var spawn_timer := 0.0
var pickup_timer := 0.0
var elapsed := 0.0
var invulnerable := 0.0
var blade_angle := 0.0
var blade_flash := 0.0
var player_hit_flash := 0.0
var mode := "start"
var status := "UNARMED - COLLECT YOUR FIRST RELIC"
var crown_coins := 0
var run_kills := 0
var run_coins_earned := 0
var meta_damage := 0
var meta_health := 0
var meta_range := 0
var meta_file := "user://crown_meta.cfg"
var ascension_options: Array[String] = []
var ascension_positions := [Vector2(390, 385), Vector2(640, 385), Vector2(890, 385)]
var hud_labels: Dictionary = {}

func _ready() -> void:
    load_meta()
    setup_hud()
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    if mode == "play": update_game(delta)
    blade_flash = max(0.0, blade_flash - delta)
    player_hit_flash = max(0.0, player_hit_flash - delta)
    for id in weapon_swings.keys(): weapon_swings[id] = max(0.0, float(weapon_swings[id]) - delta)
    for impact in melee_impacts: impact.life = max(0.0, float(impact.life) - delta)
    melee_impacts = melee_impacts.filter(func(impact: Dictionary) -> bool: return impact.life > 0.0)
    for burst in enemy_bursts: burst.life = max(0.0, float(burst.life) - delta)
    enemy_bursts = enemy_bursts.filter(func(burst: Dictionary) -> bool: return burst.life > 0.0)
    invulnerable = max(0.0, invulnerable - delta)
    update_hud()
    queue_redraw()

func setup_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.color = Color(0.03, 0.06, 0.12, 0.88)
    panel.position = Vector2(24, 20)
    panel.size = Vector2(1232, 72)
    layer.add_child(panel)
    hud_labels["title"] = make_label(layer, Vector2(44, 31), "CROWN OF THE ABSOLUTE", 24, Color("f2f0d0"))
    hud_labels["stats"] = make_label(layer, Vector2(650, 32), "", 14, Color("edc968"))
    hud_labels["status"] = make_label(layer, Vector2(44, 122), "", 13, Color("63d1c2"))
    hud_labels["build"] = make_label(layer, Vector2(44, 675), "", 13, Color("aebbb2"))
    hud_labels["help"] = make_label(layer, Vector2(930, 675), "WASD / ARROWS  ·  R RESTART", 12, Color("879b9b"))

func make_label(parent: Node, position: Vector2, text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = position
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func update_hud() -> void:
    if hud_labels.is_empty(): return
    hud_labels["stats"].text = "VESSEL %02d     ESSENCE %03d     WAVE %02d / 05     VITALITY %03d" % [level, essence, wave, max(0, int(player.health))]
    hud_labels["status"].text = status
    hud_labels["build"].text = "PATH: %s     ACTIVE WEAPONS: %s / %d     %s" % [weapon_family if not weapon_family.is_empty() else "UNARMED", ", ".join(equipped) if not equipped.is_empty() else "NONE", MAX_WEAPONS, "CROWN COINS: %d" % crown_coins]

func load_meta() -> void:
    var config := ConfigFile.new()
    if config.load(meta_file) == OK:
        crown_coins = int(config.get_value("meta", "coins", 0))
        meta_damage = int(config.get_value("meta", "damage", 0))
        meta_health = int(config.get_value("meta", "health", 0))
        meta_range = int(config.get_value("meta", "range", 0))

func save_meta() -> void:
    var config := ConfigFile.new()
    config.set_value("meta", "coins", crown_coins)
    config.set_value("meta", "damage", meta_damage)
    config.set_value("meta", "health", meta_health)
    config.set_value("meta", "range", meta_range)
    config.save(meta_file)

func load_path_nodes() -> void:
    var config := ConfigFile.new()
    if config.load(meta_file) == OK:
        for node in config.get_value("paths", weapon_family, []): unlocked_nodes[node] = true

func save_path_nodes() -> void:
    if weapon_family.is_empty(): return
    var config := ConfigFile.new()
    config.load(meta_file)
    config.set_value("paths", weapon_family, unlocked_nodes.keys())
    config.save(meta_file)

func start_game() -> void:
    mode = "play"
    level = 1; essence = 0; wave = 1; boss_spawned = false; run_kills = 0; run_coins_earned = 0; player_hit_flash = 0.0; equipped.clear(); weapon_ranks.clear(); unlocked_nodes.clear(); weapon_cooldowns.clear(); weapon_swings.clear(); melee_impacts.clear(); enemy_bursts.clear(); enemies.clear(); projectiles.clear(); pickups.clear();
    weapon_family = ""; spawn_timer = 0.0; pickup_timer = 0.0; ascension_options.clear()
    player = {"position": ARENA_SIZE * 0.5, "health": 85.0 + meta_health * 12.0, "max_health": 85.0 + meta_health * 12.0, "speed": 235.0}
    pickups.append({"position": player.position + Vector2(100, 0), "name": "VOID BLADE", "family": "MELEE", "life": 40.0})
    pickups.append({"position": player.position + Vector2(-100, 0), "name": "STAR BOLT", "family": "RANGED", "life": 40.0})
    status = "CHOOSE YOUR FIRST PATH"
    update_hud()

func update_game(delta: float) -> void:
    var movement := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y += 1
    if movement.length() > 0: player.position += movement.normalized() * player.speed * delta
    player.position.x = clamp(player.position.x, 35.0, ARENA_SIZE.x - 35.0)
    player.position.y = clamp(player.position.y, 35.0, ARENA_SIZE.y - 35.0)
    spawn_timer -= delta; pickup_timer -= delta
    if spawn_timer <= 0.0:
        spawn_enemy(); spawn_timer = max(0.2, 0.9 - wave * 0.1)
    if pickup_timer <= 0.0 and not weapon_family.is_empty() and pickups.size() < 5:
        spawn_pickup(); pickup_timer = 4.0
    collect_pickups(); auto_cast(delta); update_projectiles(delta); update_enemies(delta)
    if enemies.size() > 12 + wave * 3:
        var previous_wave: int = wave
        wave = min(5, wave + 1)
        if wave > previous_wave:
            status = "WAVE %02d REACHED - THREATS ESCALATING" % wave
    player.health = min(player.max_health, player.health + float(meta_health) * 0.02 * delta)

func spawn_enemy() -> void:
    var side := randi() % 4
    var position := Vector2.ZERO
    if side == 0: position = Vector2(-35, randf_range(0, ARENA_SIZE.y))
    elif side == 1: position = Vector2(ARENA_SIZE.x + 35, randf_range(0, ARENA_SIZE.y))
    elif side == 2: position = Vector2(randf_range(0, ARENA_SIZE.x), -35)
    else: position = Vector2(randf_range(0, ARENA_SIZE.x), ARENA_SIZE.y + 35)
    var roll := randf(); var type := "WISP"
    if wave >= 5 and not boss_spawned:
        type = "DREAD REGENT"
        boss_spawned = true
        status = "THE DREAD REGENT HAS ENTERED THE ARENA"
    elif roll < 0.2: type = "BRUTE"
    elif roll < 0.36: type = "CHARGER"
    elif roll < 0.5: type = "SPLITTER"
    elif roll < 0.64: type = "LEECH"
    elif roll < 0.78: type = "ORACLE"
    var data: Dictionary = MONSTERS[type]
    var health: float = data.health + wave * 14.0
    enemies.append({"position": position, "type": type, "radius": data.radius, "health": health, "max_health": health, "speed": data.speed + wave * 4.0, "damage": data.damage, "essence": data.essence, "shot_timer": 1.5, "poison": 0.0, "slow": 0.0, "hit_flash": 0.0})

func spawn_pickup() -> void:
    var options: Array[String] = []
    for weapon in WEAPONS:
        if weapon_family == WEAPONS[weapon].family and not equipped.has(weapon): options.append(weapon)
    for upgrade in UPGRADES:
        if weapon_family == UPGRADES[upgrade].family and not unlocked_nodes.has(upgrade): options.append(upgrade)
    if options.is_empty(): return
    var id: String = options.pick_random()
    pickups.append({"position": Vector2(randf_range(90, ARENA_SIZE.x - 90), randf_range(90, ARENA_SIZE.y - 90)), "name": id, "family": weapon_family, "life": 25.0})

func collect_pickups() -> void:
    for pickup in pickups.duplicate():
        pickup.life -= get_process_delta_time()
        if player.position.distance_to(pickup.position) < 40.0 + meta_range * 12.0:
            var id: String = pickup.name
            if WEAPONS.has(id):
                if weapon_family.is_empty():
                    weapon_family = WEAPONS[id].family
                    load_path_nodes()
                    for other_pickup in pickups.duplicate():
                        if WEAPONS.has(other_pickup.name) and WEAPONS[other_pickup.name].family != weapon_family:
                            pickups.erase(other_pickup)
                if WEAPONS[id].family != weapon_family:
                    pickups.erase(pickup)
                    continue
                unlocked_nodes[id] = true
                save_path_nodes()
                weapon_ranks[id] = int(weapon_ranks.get(id, 0)) + 1
                if not equipped.has(id) and equipped.size() < MAX_WEAPONS: equipped.append(id); weapon_cooldowns[id] = 0.0
            elif UPGRADES.has(id):
                if UPGRADES[id].family != weapon_family:
                    pickups.erase(pickup)
                    continue
                unlocked_nodes[id] = true; save_path_nodes(); apply_upgrade(id)
            status = "%s CLAIMED / %s PATH" % [id, weapon_family]
            pickups.erase(pickup)
    pickups = pickups.filter(func(item: Dictionary) -> bool: return item.life > 0.0)

func apply_upgrade(id: String) -> void:
    if id == "WAR BLESSING": meta_damage += 1
    elif id == "QUICKENED RITE": pass
    elif id == "IRON SOUL": player.max_health += 35.0; player.health = player.max_health
    elif id == "GRAVITY HAND": meta_range += 1
    elif id == "ARSENAL MASTERY": meta_damage += 1
    elif id == "EXECUTIONER RITE": pass
    elif id == "BLOOD OF STARS": pass
    elif id == "CROWNWARD": invulnerable += 0.35

func auto_cast(delta: float) -> void:
    if enemies.is_empty() or equipped.is_empty(): return
    var target: Dictionary = nearest_enemy()
    for weapon in equipped:
        weapon_cooldowns[weapon] = max(0.0, float(weapon_cooldowns.get(weapon, 0.0)) - delta)
        if weapon_cooldowns[weapon] <= 0.0:
            fire_weapon(weapon, target)

func fire_weapon(id: String, target: Dictionary) -> void:
    var data: Dictionary = WEAPONS[id]; weapon_cooldowns[id] = data.cooldown
    var power: float = weapon_power(id)
    var angle: float = player.position.angle_to_point(target.position)
    if data.kind in ["blade", "nova", "chain"]:
        weapon_swings[id] = float(data.get("swing_time", 0.3))
        weapon_swings[id + "_angle"] = angle
        blade_angle = angle
        blade_flash = max(blade_flash, float(data.get("swing_time", 0.3)))
        var reach: float = float(data.get("reach", 110.0))
        var arc: float = float(data.get("swing_arc", 1.2))
        var damage_mult: float = float(data.get("damage_mult", 1.0))
        for enemy in enemies:
            var relative: Vector2 = enemy.position - player.position
            var dist: float = relative.length()
            var relative_angle: float = abs(wrapf(relative.angle() - angle, -PI, PI))
            if dist <= reach and relative_angle <= arc * 0.5:
                var hit: float = power * damage_mult
                if data.kind == "blade":
                    hit *= 1.25 if dist < reach * 0.6 else 0.95
                elif data.kind == "nova":
                    hit *= 1.4 if dist < reach * 0.75 else 0.85
                    enemy.slow = max(enemy.slow, 0.7)
                elif data.kind == "chain":
                    hit *= 1.25 if dist > reach * 0.7 else 0.9
                    enemy.poison = max(enemy.poison, 1.0)
                enemy.health -= hit
                enemy.hit_flash = 0.14
                var recoil: float = 10.0 if data.kind == "blade" else 18.0 if data.kind == "nova" else 7.0
                enemy.position += relative.normalized() * recoil
                melee_impacts.append({"position": enemy.position, "style": data.style, "color": data.color, "life": 0.22})
    elif data.kind == "storm":
        for enemy in enemies:
            if enemy.position.distance_to(target.position) < 185.0: enemy.health -= power * 1.1
    elif data.kind == "meteor": projectiles.append({"position": target.position, "velocity": Vector2.ZERO, "life": 0.5, "radius": 48.0, "damage": power * 2.6, "color": data.color, "impact": true})
    else: projectiles.append({"position": player.position, "velocity": Vector2(cos(angle), sin(angle)) * 560.0, "life": 1.5, "radius": 8.0, "damage": power, "color": data.color, "kind": data.kind, "impact": false})

func weapon_power(id: String) -> float:
    var rank: int = int(weapon_ranks.get(id, 1))
    var mastery: float = 1.18 if unlocked_nodes.has("ARSENAL MASTERY") else 1.0
    return (22.0 + meta_damage * 5.0) * mastery * pow(float(rank), 0.35)

func nearest_enemy() -> Dictionary:
    var nearest: Dictionary = enemies[0]
    for enemy in enemies:
        if enemy.position.distance_to(player.position) < nearest.position.distance_to(player.position): nearest = enemy
    return nearest

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
                    if projectile.kind == "frost": enemy.slow = 1.8
                    if projectile.kind == "venom": enemy.poison = 3.0
                    projectile.life = 0.0
        if projectile.life <= 0.0: projectiles.erase(projectile)

func update_enemies(delta: float) -> void:
    for enemy in enemies.duplicate():
        var angle: float = enemy.position.angle_to_point(player.position)
        var separation: float = -1.0 if enemy.type == "ORACLE" and enemy.position.distance_to(player.position) < 240.0 else 1.0
        enemy.slow = max(0.0, enemy.slow - delta); enemy.poison = max(0.0, enemy.poison - delta); enemy.hit_flash = max(0.0, enemy.hit_flash - delta)
        enemy.health -= 7.0 * delta if enemy.poison > 0.0 else 0.0
        enemy.position += Vector2(cos(angle), sin(angle)) * enemy.speed * separation * (0.45 if enemy.slow > 0 else 1.0) * delta
        if enemy.position.distance_to(player.position) < enemy.radius + 17.0: damage_player(enemy.damage * delta)
        if enemy.health <= 0.0:
            essence += enemy.essence
            run_kills += 1
            enemy_bursts.append({"position": enemy.position, "color": MONSTERS[enemy.type].color, "radius": enemy.radius, "life": 0.32})
            enemies.erase(enemy)
            if enemy.type == "DREAD REGENT":
                mode = "victory"
                crown_coins += 50
                run_coins_earned = 50
                save_meta()
                status = "THE DREAD REGENT FALLS - 50 BONUS CROWN COINS"

        if essence >= 240 and mode == "play": open_ascension()

func open_ascension() -> void:
    mode = "ascension"
    ascension_options.clear()
    var candidates: Array[String] = []
    for id in WEAPONS:
        if WEAPONS[id].family == weapon_family and not unlocked_nodes.has(id) and equipped.size() < MAX_WEAPONS: candidates.append(id)
    for id in UPGRADES:
        if UPGRADES[id].family == weapon_family and not unlocked_nodes.has(id): candidates.append(id)
    candidates.shuffle()
    for id in candidates:
        if ascension_options.size() >= 3: break
        ascension_options.append(id)
    status = "ASCENSION WEB - CHOOSE A CONNECTED NODE"

func choose_ascension(index: int) -> void:
    if index < 0 or index >= ascension_options.size(): return
    var id: String = ascension_options[index]
    unlocked_nodes[id] = true
    save_path_nodes()
    if WEAPONS.has(id) and not equipped.has(id) and equipped.size() < MAX_WEAPONS:
        equipped.append(id); weapon_cooldowns[id] = 0.0
    elif UPGRADES.has(id): apply_upgrade(id)
    level += 1
    mode = "play"
    status = "%s UNLOCKED - PATH EXPANDED" % id

func damage_player(amount: float) -> void:
    if invulnerable > 0.0: return
    invulnerable = 0.7; player_hit_flash = 0.2; player.health -= amount
    if player.health <= 0.0: die()

func die() -> void:
    mode = "death"
    run_coins_earned = max(5, essence / 12 + level * 3)
    crown_coins += run_coins_earned
    save_meta()
    status = "VESSEL LOST - %d CROWN COINS" % crown_coins

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_R: start_game()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode == "start": start_game()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode == "ascension":
        for index in ascension_positions.size():
            if Rect2(ascension_positions[index] - Vector2(100, 44), Vector2(200, 88)).has_point(event.position): choose_ascension(index)
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode == "death":
        if Rect2(Vector2(410, 430), Vector2(190, 70)).has_point(event.position): buy_meta("damage", 30)
        elif Rect2(Vector2(625, 430), Vector2(190, 70)).has_point(event.position): buy_meta("health", 35)
        elif Rect2(Vector2(840, 430), Vector2(190, 70)).has_point(event.position): buy_meta("range", 25)

func buy_meta(kind: String, cost: int) -> void:
    if crown_coins < cost: return
    crown_coins -= cost
    if kind == "damage": meta_damage += 1
    elif kind == "health": meta_health += 1
    elif kind == "range": meta_range += 1
    save_meta()

func draw_monster(enemy: Dictionary, data: Dictionary) -> void:
    var position: Vector2 = enemy.position
    var radius: float = enemy.radius
    draw_ellipse_custom(position + Vector2(radius * 0.15, radius * 0.72), Vector2(radius * 0.95, radius * 0.3), Color(0, 0, 0, 0.4))
    draw_circle(position, radius + 4, Color(data.color, 0.08))
    if enemy.type == "DREAD REGENT":
        draw_circle(position + Vector2(0, radius * 0.35), radius * 1.35, Color(0.93, 0.79, 0.4, 0.06 + sin(elapsed * 3.0) * 0.02))
        draw_arc(position, radius * 1.45, elapsed * 0.7, elapsed * 0.7 + PI * 1.4, 28, Color(0.93, 0.79, 0.4, 0.3), 2.0)
    if enemy.type == "BRUTE" or enemy.type == "DREAD REGENT":
        var body := PackedVector2Array([position + Vector2(-radius, -radius * .55), position + Vector2(-radius * .7, -radius), position + Vector2(radius * .7, -radius), position + Vector2(radius, -radius * .55), position + Vector2(radius * .8, radius), position + Vector2(-radius * .8, radius)])
        draw_colored_polygon(body, Color("101826")); draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], body[0]]), data.color, 3.0)
        draw_line(position + Vector2(-radius * .65, -radius * .7), position + Vector2(-radius * .35, -radius - 10), data.color, 4.0); draw_line(position + Vector2(radius * .35, -radius * .7), position + Vector2(radius * .65, -radius - 10), data.color, 4.0)
        if enemy.type == "DREAD REGENT":
            var crown := PackedVector2Array([position + Vector2(-radius * .7, -radius * .8), position + Vector2(-radius * .45, -radius * 1.35), position + Vector2(-radius * .12, -radius * .95), position + Vector2(radius * .2, -radius * 1.4), position + Vector2(radius * .65, -radius * .78)])
            draw_polyline(crown, Color("edc968"), 4.0)
            draw_circle(position + Vector2(-radius * .45, -radius * 1.12), 3.0, Color("ed725c"))
            draw_circle(position + Vector2(radius * .2, -radius * 1.18), 3.0, Color("63d1c2"))
    elif enemy.type == "CHARGER":
        var horned := PackedVector2Array([position + Vector2(radius + 9, 0), position + Vector2(0, radius), position + Vector2(-radius, radius * .45), position + Vector2(-radius, -radius * .45), position + Vector2(0, -radius)])
        draw_colored_polygon(horned, Color("101826")); draw_polyline(PackedVector2Array([horned[0], horned[1], horned[2], horned[3], horned[4], horned[0]]), data.color, 3.0)
    elif enemy.type == "SPLITTER":
        draw_circle(position, radius, Color("101826")); draw_arc(position, radius, 0, TAU, 16, data.color, 3.0); draw_line(position + Vector2(-radius, 0), position + Vector2(radius, 0), data.color, 2.0)
    elif enemy.type == "LEECH":
        draw_set_transform(position, atan2(player.position.y - position.y, player.position.x - position.x)); draw_ellipse_custom(Vector2.ZERO, Vector2(radius * 1.45, radius * .65), Color("101826")); draw_arc(Vector2.ZERO, radius * .8, 0, TAU, 16, data.color, 3.0); draw_set_transform(Vector2.ZERO, 0.0)
    else:
        var wisp := PackedVector2Array([position + Vector2(0, -radius - 5), position + Vector2(radius, 0), position + Vector2(0, radius + 5), position + Vector2(-radius, 0)])
        draw_colored_polygon(wisp, Color("101826")); draw_polyline(PackedVector2Array([wisp[0], wisp[1], wisp[2], wisp[3], wisp[0]]), data.color, 3.0)
    if enemy.type == "WISP":
        draw_circle(position, radius * 0.42, Color(data.color, 0.28))
        draw_circle(position, radius * 0.16, Color("f2f0d0"))
    elif enemy.type == "BRUTE":
        draw_line(position + Vector2(-radius * 0.58, 0), position + Vector2(-radius * 0.25, radius * 0.55), Color("53656a"), 3.0)
        draw_line(position + Vector2(radius * 0.58, 0), position + Vector2(radius * 0.25, radius * 0.55), Color("53656a"), 3.0)
    elif enemy.type == "CHARGER":
        draw_line(position + Vector2(radius * 0.1, -radius * 0.35), position + Vector2(radius * 0.55, -radius * 0.1), Color("f2f0d0"), 2.0)
        draw_circle(position + Vector2(radius * 0.38, -radius * 0.08), 2.5, Color("ed725c"))
    elif enemy.type == "SPLITTER":
        draw_line(position + Vector2(-radius * 0.65, -radius * 0.3), position + Vector2(-radius * 0.2, radius * 0.15), data.color, 2.0)
        draw_line(position + Vector2(radius * 0.1, radius * 0.4), position + Vector2(radius * 0.55, radius * 0.05), data.color, 2.0)
    elif enemy.type == "LEECH":
        draw_line(position + Vector2(radius * 0.55, -radius * 0.22), position + Vector2(radius * 0.9, 0), data.color, 2.0)
        draw_line(position + Vector2(radius * 0.55, radius * 0.22), position + Vector2(radius * 0.9, 0), data.color, 2.0)
    elif enemy.type == "ORACLE":
        draw_circle(position, radius * 0.5, Color("101826"))
        draw_arc(position, radius * 0.52, elapsed * 0.9, elapsed * 0.9 + PI, 12, data.color, 2.0)
    var enemy_color: Color = Color("ffffff") if enemy.hit_flash > 0.0 else data.color
    var gaze: Vector2 = (player.position - position).normalized()
    var gaze_side: Vector2 = Vector2(-gaze.y, gaze.x)
    var breathe: float = sin(elapsed * 3.0 + position.x * 0.01) * radius * 0.04
    var eye_center: Vector2 = position + gaze * (radius * 0.24 + breathe)
    draw_circle(eye_center - gaze_side * radius * 0.18, 3.0, enemy_color)
    draw_circle(eye_center + gaze_side * radius * 0.18, 3.0, enemy_color)
    draw_circle(position + Vector2(-radius * 0.3, radius * 0.45), radius * 0.16, Color(enemy_color, 0.18))
    if enemy.hit_flash > 0.0:
        draw_arc(position, radius + 5.0, 0, TAU, 20, Color(1.0, 0.9, 0.65, enemy.hit_flash / 0.14), 3.0)
    draw_circle(position - Vector2(radius * .25, radius * .28), radius * .25, Color(enemy_color, 0.16))
    var health_ratio: float = max(0.0, enemy.health / enemy.max_health)
    var meter := Rect2(position + Vector2(-radius, -radius - 14), Vector2(radius * 2.0, 6.0))
    draw_rect(meter, Color(0.02, 0.04, 0.07, 0.9))
    var meter_color: Color = Color("ed725c") if health_ratio < 0.3 else data.color
    draw_rect(Rect2(meter.position + Vector2(1, 1), Vector2(max(0.0, (meter.size.x - 2.0) * health_ratio), 4.0)), meter_color)

func draw_ellipse_custom(center: Vector2, radius: Vector2, color: Color) -> void:
    var points := PackedVector2Array()
    for index in range(24):
        var angle := TAU * float(index) / 24.0
        points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
    draw_colored_polygon(points, color)

func draw_knight() -> void:
    var position: Vector2 = player.position
    var health_ratio: float = clamp(player.health / player.max_health, 0.0, 1.0)
    var health_color := Color("63d1c2") if health_ratio > 0.35 else Color("ed725c")
    draw_arc(position, 45.0, -PI * 0.5, -PI * 0.5 + TAU * health_ratio, 28, health_color, 3.0)
    draw_arc(position, 45.0, -PI * 0.5 + TAU * health_ratio, PI * 1.5, 28, Color(0.08, 0.12, 0.16, 0.75), 3.0)
    if player_hit_flash > 0.0:
        var impact_fade: float = player_hit_flash / 0.2
        draw_circle(position, 48.0 - impact_fade * 12.0, Color(1.0, 0.42, 0.3, 0.12 * impact_fade))
        draw_arc(position, 36.0 + (1.0 - impact_fade) * 20.0, 0, TAU, 20, Color(1.0, 0.75, 0.5, impact_fade), 3.0)
    draw_ellipse_custom(position + Vector2(0, 27), Vector2(32, 10), Color(0, 0, 0, .48))
    draw_line(position + Vector2(-17, 5), position + Vector2(-31, 28), Color("aebbb2"), 8.0); draw_line(position + Vector2(17, 5), position + Vector2(31, 28), Color("aebbb2"), 8.0)
    draw_line(position + Vector2(-11, 16), position + Vector2(-14, 42), Color("53656a"), 10.0); draw_line(position + Vector2(11, 16), position + Vector2(14, 42), Color("53656a"), 10.0)
    draw_circle(position + Vector2(-31, 28), 7.0, Color("edc968")); draw_circle(position + Vector2(31, 28), 7.0, Color("edc968"))
    var armor := PackedVector2Array([position + Vector2(-20, -4), position + Vector2(-14, -25), position + Vector2(0, -38), position + Vector2(14, -25), position + Vector2(20, -4), position + Vector2(16, 22), position + Vector2(-16, 22)])
    var armor_color := Color("ffffff") if player_hit_flash > 0.0 else Color("aebbb2")
    draw_colored_polygon(armor, armor_color); draw_polyline(PackedVector2Array([armor[0], armor[1], armor[2], armor[3], armor[4], armor[5], armor[6], armor[0]]), Color("edc968"), 3.0)
    draw_colored_polygon(PackedVector2Array([position + Vector2(-13, -22), position + Vector2(0, -34), position + Vector2(10, -23), position + Vector2(5, -5), position + Vector2(-10, -5)]), Color("dbe6df"))
    draw_line(position + Vector2(-8, -7), position + Vector2(8, -7), Color("607b80"), 2.0)
    draw_line(position + Vector2(-16, -5), position + Vector2(16, -5), Color("263744"), 7.0)
    draw_line(position + Vector2(-13, -25), position + Vector2(0, -48), Color("edc968"), 5.0); draw_line(position + Vector2(13, -25), position + Vector2(0, -48), Color("edc968"), 5.0)
    draw_line(position + Vector2(0, -35), position + Vector2(25, -50), Color("ed725c"), 6.0)
    draw_circle(position + Vector2(28, 10), 14.0, Color("607b80")); draw_arc(position + Vector2(28, 10), 14.0, 0, TAU, 16, Color("edc968"), 3.0)
    draw_line(position + Vector2(38, 20), position + Vector2(51, 39), Color("dbe6df"), 5.0)
    draw_circle(position + Vector2(-6, -17), 3.0, Color("edc968")); draw_circle(position + Vector2(6, -17), 3.0, Color("edc968"))

func draw_melee_swing(style: String, origin: Vector2, angle: float, reach: float, color: Color, intensity: float = 1.0) -> void:
    var trail_end := origin + Vector2(cos(angle), sin(angle)) * reach
    if style == "blade":
        draw_sword(origin, angle, reach, color, true)
        draw_arc(origin, reach * 0.7, angle - 0.9, angle + 0.9, 14, Color(color.r, color.g, color.b, 0.28 + intensity * 0.25), 4.0)
    elif style == "nova":
        draw_arc(origin, reach * 0.96, angle - 1.5, angle + 1.5, 22, Color(color.r, color.g, color.b, 0.2 + intensity * 0.35), 5.0)
        draw_line(origin, origin + Vector2(cos(angle - 1.1), sin(angle - 1.1)) * reach, color, 6.0)
        draw_line(origin, origin + Vector2(cos(angle + 1.1), sin(angle + 1.1)) * reach, color, 6.0)
        draw_circle(origin + Vector2(cos(angle), sin(angle)) * reach * 0.7, 9.0, Color(color.r, color.g, color.b, 0.36))
    elif style == "chain":
        draw_line(origin, trail_end, color, 4.0)
        for step in range(1, 5):
            var point := origin.lerp(trail_end, float(step) / 5.0)
            draw_circle(point, 4.0 + float(step) * 1.4, Color("f2f0d0"))
        draw_arc(origin, reach * 0.8, angle - 2.1, angle + 2.1, 18, Color(color.r, color.g, color.b, 0.18 + intensity * 0.22), 3.0)

func draw_sword(origin: Vector2, angle: float, length: float, color: Color, swung: bool = false) -> void:
    var direction := Vector2(cos(angle), sin(angle))
    var side := Vector2(-sin(angle), cos(angle))
    var grip_start := origin - direction * 16.0
    var guard_center := origin - direction * 5.0
    var blade_start := guard_center + direction * 4.0
    var tip := origin + direction * length
    var blade_width := 7.0 if swung else 5.0
    var blade := PackedVector2Array([
        blade_start + side * blade_width,
        tip - direction * 8.0 + side * 2.0,
        tip,
        tip - direction * 8.0 - side * 2.0,
        blade_start - side * blade_width
    ])
    draw_colored_polygon(blade, Color("dbe6df"))
    draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[3], blade[4], blade[0]]), Color("53656a"), 2.0)
    var fuller_start := blade_start + direction * 5.0 + side * 1.5
    var fuller_end := tip - direction * 13.0 + side * 0.7
    draw_line(fuller_start, fuller_end, Color("8b9da0"), 2.0)
    draw_line(blade_start + side * 1.0, tip - direction * 10.0 + side * 0.5, Color("ffffff"), 1.5)
    draw_line(guard_center - side * 13.0, guard_center + side * 13.0, color, 5.0)
    draw_line(grip_start, guard_center - direction * 2.0, Color("3a2528"), 7.0)
    draw_line(grip_start, guard_center - direction * 2.0, Color("8b5550"), 2.0)
    for band in range(3):
        var band_center := grip_start + direction * (5.0 + band * 6.0)
        draw_line(band_center - side * 3.0, band_center + side * 3.0, Color("c27a68"), 1.5)
    draw_circle(grip_start - direction * 3.0, 5.0, color)

func draw_melee_impact(impact: Dictionary) -> void:
    var position: Vector2 = impact.position
    var color: Color = impact.color
    var progress: float = 1.0 - float(impact.life) / 0.22
    var fade: float = float(impact.life) / 0.22
    if impact.style == "blade":
        draw_line(position + Vector2(-10, -10) * (1.0 + progress), position + Vector2(10, 10) * (1.0 + progress), Color(1.0, 0.94, 0.65, fade), 3.0)
        draw_line(position + Vector2(10, -10) * (1.0 + progress), position + Vector2(-10, 10) * (1.0 + progress), color * Color(1, 1, 1, fade), 2.0)
    elif impact.style == "nova":
        draw_circle(position, 16.0 + progress * 18.0, Color(color.r, color.g, color.b, 0.12 * fade))
        draw_arc(position, 12.0 + progress * 20.0, 0, TAU, 16, Color(color.r, color.g, color.b, fade), 3.0)
    elif impact.style == "chain":
        draw_circle(position, 6.0 + progress * 7.0, Color("f2f0d0"))
        draw_arc(position, 12.0 + progress * 14.0, 0, TAU, 12, Color(color.r, color.g, color.b, fade), 3.0)

func draw_enemy_burst(burst: Dictionary) -> void:
    var progress: float = 1.0 - float(burst.life) / 0.32
    var fade: float = float(burst.life) / 0.32
    var position: Vector2 = burst.position
    var radius: float = float(burst.radius) * (0.8 + progress * 1.8)
    var color: Color = burst.color
    draw_circle(position, radius * 0.35, Color(color.r, color.g, color.b, 0.16 * fade))
    draw_arc(position, radius, 0, TAU, 18, Color(color.r, color.g, color.b, fade), 3.0)
    for ray in range(6):
        var ray_angle := TAU * float(ray) / 6.0 + progress
        var ray_start := position + Vector2(cos(ray_angle), sin(ray_angle)) * radius * 0.75
        var ray_end := position + Vector2(cos(ray_angle), sin(ray_angle)) * radius * 1.35
        draw_line(ray_start, ray_end, Color(1.0, 0.9, 0.65, fade), 2.0)

func draw_equipped_weapon(id: String, index: int, total: int) -> void:
    var data: Dictionary = WEAPONS[id]
    var orbit_angle: float = TAU * float(index) / float(max(1, total)) - PI / 2.0
    orbit_angle += elapsed * float(data.get("orbit_speed", 0.0))
    var angle: float = orbit_angle
    var radius: float = 45.0
    var style: String = data.get("style", "blade")
    var swing_remaining: float = float(weapon_swings.get(id, 0.0))
    if data.family == "MELEE" and swing_remaining > 0.0:
        var swing_time: float = float(data.get("swing_time", 0.3))
        var progress: float = 1.0 - swing_remaining / max(0.01, swing_time)
        var attack_angle: float = float(weapon_swings.get(id + "_angle", blade_angle))
        angle = attack_angle - float(data.get("swing_arc", 1.2)) * 0.5 + progress * float(data.get("swing_arc", 1.2))
        radius = 18.0
        draw_melee_swing(style, player.position, angle, float(data.get("reach", 90.0)), data.color, swing_remaining / max(0.01, swing_time))
        return
    var anchor: Vector2 = player.position + Vector2(cos(angle), sin(angle)) * radius
    if data.family == "MELEE":
        var idle_reach: float = float(data.get("reach", 90.0)) * 0.4
        if style == "blade":
            draw_sword(anchor, angle, idle_reach, data.color)
        elif style == "nova":
            draw_arc(anchor, idle_reach * 0.45, 0, TAU, 16, data.color, 3.0)
            draw_circle(anchor, 5.0, data.color)
        elif style == "chain":
            draw_line(anchor, anchor + Vector2(cos(angle), sin(angle)) * idle_reach, data.color, 4.0)
            draw_circle(anchor + Vector2(cos(angle), sin(angle)) * idle_reach * 0.65, 5.0, Color("f2f0d0"))
        return
    if id == "STAR BOLT":
        draw_colored_polygon(PackedVector2Array([anchor + Vector2(0, -12), anchor + Vector2(7, 0), anchor + Vector2(0, 12), anchor + Vector2(-7, 0)]), data.color)
    elif id == "GRAVITY NOVA":
        draw_arc(anchor, 12.0, 0, TAU, 16, data.color, 3.0); draw_circle(anchor, 4.0, data.color)
    elif id == "SOUL CHAIN":
        draw_arc(anchor + Vector2(0, -7), 7.0, 0, TAU, 12, data.color, 3.0); draw_arc(anchor + Vector2(0, 8), 7.0, 0, TAU, 12, data.color, 3.0)
    elif id == "ROYAL METEOR":
        draw_colored_polygon(PackedVector2Array([anchor + Vector2(0, -15), anchor + Vector2(9, 5), anchor + Vector2(0, 13), anchor + Vector2(-9, 5)]), data.color)
    elif id == "FROST LANCE":
        draw_colored_polygon(PackedVector2Array([anchor + Vector2(0, -16), anchor + Vector2(8, 0), anchor + Vector2(0, 16), anchor + Vector2(-8, 0)]), data.color)
    elif id == "VENOM ORB":
        draw_circle(anchor, 11.0, data.color); draw_arc(anchor, 11.0, 0, TAU, 16, Color("d9ffb7"), 2.0)
    elif id == "STORM SIGIL":
        draw_colored_polygon(PackedVector2Array([anchor + Vector2(6, -16), anchor + Vector2(-4, -2), anchor + Vector2(3, -2), anchor + Vector2(-7, 16), anchor + Vector2(8, 1), anchor + Vector2(1, 1)]), data.color)

func _draw() -> void:
    var field := Rect2(Vector2.ZERO, ARENA_SIZE)
    draw_rect(field, Color("0b1425"))
    draw_circle(ARENA_SIZE * .5, 330.0, Color(0.12, 0.2, 0.34, .32))
    draw_circle(ARENA_SIZE * .5, 260.0, Color(0.22, 0.28, 0.34, .08))
    for x in range(0, int(ARENA_SIZE.x), 48): draw_line(Vector2(x, 0), Vector2(x, ARENA_SIZE.y), Color(1, 1, 1, 0.035))
    for y in range(0, int(ARENA_SIZE.y), 48): draw_line(Vector2(0, y), Vector2(ARENA_SIZE.x, y), Color(1, 1, 1, 0.035))
    for stone in range(34):
        var stone_angle := TAU * float(stone) / 34.0
        var stone_position := ARENA_SIZE * 0.5 + Vector2(cos(stone_angle), sin(stone_angle)) * (220.0 + float(stone % 3) * 34.0)
        draw_circle(stone_position, 2.0 + float(stone % 2), Color(0.45, 0.52, 0.52, 0.13))
    draw_polyline(PackedVector2Array([Vector2(26, 26), Vector2(ARENA_SIZE.x - 26, 26), Vector2(ARENA_SIZE.x - 26, ARENA_SIZE.y - 26), Vector2(26, ARENA_SIZE.y - 26), Vector2(26, 26)]), Color(0.93, .79, .4, .22), 2.0)
    for pickup in pickups:
        var data: Dictionary = WEAPONS[pickup.name] if WEAPONS.has(pickup.name) else UPGRADES[pickup.name]
        draw_circle(pickup.position, 34.0 + sin(elapsed * 4.0) * 5.0, Color(data.color, 0.15))
        var diamond := PackedVector2Array([pickup.position + Vector2(0, -22), pickup.position + Vector2(22, 0), pickup.position + Vector2(0, 22), pickup.position + Vector2(-22, 0)])
        draw_colored_polygon(diamond, Color("18253a")); draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), data.color, 3.0)
        if WEAPONS.has(pickup.name):
            if data.family == "MELEE" and data.style == "blade":
                draw_sword(pickup.position, -PI * 0.5, 24.0, data.color)
            elif data.family == "MELEE" and data.style == "nova":
                draw_arc(pickup.position, 13.0, 0, TAU, 18, data.color, 3.0); draw_circle(pickup.position, 4.0, data.color)
            elif data.family == "MELEE" and data.style == "chain":
                draw_line(pickup.position + Vector2(-14, 0), pickup.position + Vector2(14, 0), data.color, 3.0); draw_circle(pickup.position + Vector2(-8, 0), 4.0, Color("f2f0d0")); draw_circle(pickup.position + Vector2(8, 0), 5.0, Color("f2f0d0"))
        draw_string(ThemeDB.fallback_font, pickup.position + Vector2(-55, 42), pickup.name, HORIZONTAL_ALIGNMENT_CENTER, 110, 10, Color("edf2e9")); draw_string(ThemeDB.fallback_font, pickup.position + Vector2(-55, 56), pickup.family, HORIZONTAL_ALIGNMENT_CENTER, 110, 8, data.color)
        if data.family == "MELEE":
            draw_string(ThemeDB.fallback_font, pickup.position + Vector2(-75, 70), "%s  |  %s" % [data.strength, data.weakness], HORIZONTAL_ALIGNMENT_CENTER, 150, 7, Color("aebbb2"))
    for projectile in projectiles:
        if projectile.impact:
            draw_circle(projectile.position, projectile.radius + 8.0, Color(projectile.color, .18)); draw_arc(projectile.position, projectile.radius, 0, TAU, 24, projectile.color, 4.0)
        elif projectile.kind == "frost":
            var shard := PackedVector2Array([projectile.position + Vector2(0, -14), projectile.position + Vector2(8, 0), projectile.position + Vector2(0, 14), projectile.position + Vector2(-8, 0)])
            draw_colored_polygon(shard, projectile.color); draw_polyline(PackedVector2Array([shard[0], shard[1], shard[2], shard[3], shard[0]]), Color("ffffff"), 2.0)
        elif projectile.kind == "venom":
            draw_circle(projectile.position, projectile.radius + 5.0, Color(projectile.color, .18)); draw_circle(projectile.position, projectile.radius, projectile.color); draw_arc(projectile.position, projectile.radius, 0, TAU, 16, Color("d9ffb7"), 2.0)
        else:
            draw_line(projectile.position - projectile.velocity.normalized() * 14.0, projectile.position, projectile.color, 5.0); draw_circle(projectile.position, projectile.radius, projectile.color)
    for enemy in enemies:
        draw_monster(enemy, MONSTERS[enemy.type])
    for impact in melee_impacts:
        draw_melee_impact(impact)
    for burst in enemy_bursts:
        draw_enemy_burst(burst)
    if player:
        draw_knight()
        for index in equipped.size(): draw_equipped_weapon(equipped[index], index, equipped.size())
    if mode == "start": draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.04, 0.08, 0.15, .78)); draw_string(ThemeDB.fallback_font, Vector2(390, 315), "CROWN OF THE ABSOLUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("f2f0d0")); draw_string(ThemeDB.fallback_font, Vector2(430, 355), "MOVE  /  COLLECT RELICS  /  ASCEND", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("63d1c2")); draw_string(ThemeDB.fallback_font, Vector2(470, 410), "CLICK TO ENTER  ·  R TO RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aebbb2"))
    if mode == "ascension": draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.04, 0.08, 0.15, .9)); draw_string(ThemeDB.fallback_font, Vector2(410, 155), "CONNECTED ASCENSION WEB", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("f2f0d0")); draw_string(ThemeDB.fallback_font, Vector2(470, 190), "%s PATH  ·  CHOOSE ONE CONNECTED NODE" % weapon_family, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("63d1c2")); for index in ascension_positions.size(): var position: Vector2 = ascension_positions[index]; if index < ascension_options.size(): draw_line(Vector2(640, 245), position, Color(0.38, 0.5, 0.55, .7), 2.0); var id: String = ascension_options[index]; var data: Dictionary = WEAPONS[id] if WEAPONS.has(id) else UPGRADES[id]; draw_rect(Rect2(position - Vector2(100, 44), Vector2(200, 88)), Color("182d46")); draw_rect(Rect2(position - Vector2(100, 44), Vector2(200, 88)), data.color, false, 2.0); draw_string(ThemeDB.fallback_font, position + Vector2(-82, -8), id, HORIZONTAL_ALIGNMENT_LEFT, 164, 13, data.color); draw_string(ThemeDB.fallback_font, position + Vector2(-82, 16), data.get("text", "weapon node"), HORIZONTAL_ALIGNMENT_LEFT, 164, 10, Color("aebbb2"))
    if mode == "death": draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.04, 0.08, 0.15, .9)); draw_string(ThemeDB.fallback_font, Vector2(455, 220), "VESSEL LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("ed725c")); draw_string(ThemeDB.fallback_font, Vector2(455, 260), "%d CROWN COINS  ·  PRESS R TO RETURN" % crown_coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("edc968")); draw_string(ThemeDB.fallback_font, Vector2(455, 300), "WAVE %02d  ·  %d KILLS  ·  %d ESSENCE  ·  +%d COINS" % [wave, run_kills, essence, run_coins_earned], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("aebbb2")); var shop_names := ["CROWN EDGE · 30", "THRONE OF IRON · 35", "SOVEREIGN GRASP · 25"]; for index in 3: var position := Vector2(505 + index * 215, 465); draw_rect(Rect2(position - Vector2(95, 35), Vector2(190, 70)), Color("182d46")); draw_rect(Rect2(position - Vector2(95, 35), Vector2(190, 70)), Color("edc968"), false, 2.0); draw_string(ThemeDB.fallback_font, position + Vector2(-82, 5), shop_names[index], HORIZONTAL_ALIGNMENT_LEFT, 164, 11, Color("f2f0d0"))
    if mode == "victory": draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.04, 0.08, 0.15, .9)); draw_string(ThemeDB.fallback_font, Vector2(410, 220), "REGENT DEFEATED", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("63d1c2")); draw_string(ThemeDB.fallback_font, Vector2(410, 265), "THE CROWN ENDURES  ·  50 BONUS CROWN COINS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("edc968")); draw_string(ThemeDB.fallback_font, Vector2(410, 305), "WAVE %02d  ·  %d KILLS  ·  %d ESSENCE" % [wave, run_kills, essence], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("aebbb2")); draw_string(ThemeDB.fallback_font, Vector2(470, 360), "PRESS R TO BEGIN A NEW ASCENSION", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("aebbb2"))
