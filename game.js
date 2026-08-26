const canvas = document.querySelector('#gameCanvas');
const ctx = canvas.getContext('2d');
const frame = document.querySelector('.arena-frame');
const startOverlay = document.querySelector('#startOverlay');
const levelOverlay = document.querySelector('#levelOverlay');
const deathOverlay = document.querySelector('#deathOverlay');
const choices = document.querySelector('#upgradeChoices');
const levelValue = document.querySelector('#levelValue');
const essenceValue = document.querySelector('#essenceValue');
const waveValue = document.querySelector('#waveValue');
const statusValue = document.querySelector('#statusValue');
const healthBar = document.querySelector('#healthBar');
const nodePills = document.querySelector('#nodePills');
const cooldownValue = document.querySelector('#cooldownValue');
const pathBadge = document.createElement('strong');
pathBadge.textContent = 'UNARMED';
pathBadge.style.cssText = 'display:inline-block;margin-left:18px;color:#63d1c2;font:500 12px "DM Mono",monospace;letter-spacing:.08em';
document.querySelector('.hud-stats').append(pathBadge);
const keys = new Set();
const mouse = { x: 0, y: 0 };
const maxWeapons = 5;
const weapons = {
  blade: { name: 'VOID BLADE', family: 'melee', color: '#ed725c', text: 'slashes the nearest enemy', cooldown: .8 },
  bolt: { name: 'STAR BOLT', family: 'ranged', color: '#edc968', text: 'fires a piercing projectile', cooldown: .32 },
  nova: { name: 'GRAVITY NOVA', family: 'melee', color: '#63d1c2', text: 'bursts around the vessel', cooldown: 1.5 },
  chain: { name: 'SOUL CHAIN', family: 'melee', color: '#a98cff', text: 'jumps between nearby enemies', cooldown: 1.1 },
  meteor: { name: 'ROYAL METEOR', family: 'ranged', color: '#ff9b52', text: 'calls down a heavy impact', cooldown: 2.2 },
  frost: { name: 'FROST LANCE', family: 'ranged', color: '#9fd6ff', text: 'slows enemies with crystal bolts', cooldown: .65 },
  venom: { name: 'VENOM ORB', family: 'ranged', color: '#8ed66b', text: 'poisons enemies over time', cooldown: .9 },
  storm: { name: 'STORM SIGIL', family: 'ranged', color: '#d5b4ff', text: 'strikes several nearby enemies', cooldown: 1.3 }
};
const upgradeTypes = {
  damage: { name: 'WAR BLESSING', family: 'melee', color: '#ed725c', text: '+25% melee weapon damage' },
  haste: { name: 'QUICKENED RITE', family: 'ranged', color: '#edc968', text: '-18% ranged weapon cooldowns' },
  vitality: { name: 'IRON SOUL', family: 'melee', color: '#9fd6ff', text: '+35 maximum vitality' },
  magnet: { name: 'GRAVITY HAND', family: 'ranged', color: '#63d1c2', text: 'collect ranged nodes from farther away' },
  mastery: { name: 'ARSENAL MASTERY', family: 'melee', color: '#a98cff', text: '+18% damage for every melee weapon' },
  critical: { name: 'EXECUTIONER RITE', family: 'ranged', color: '#f2f0d0', text: '15% chance for ranged attacks to deal double damage' },
  regeneration: { name: 'BLOOD OF STARS', family: 'melee', color: '#ff9b52', text: 'regenerate 2 vitality each second' },
  ward: { name: 'CROWNWARD', family: 'ranged', color: '#9fd6ff', text: 'extend damage invulnerability' }
};
const nodeUpgrades = {
  critical: { name: 'EXECUTIONER RUNE', family: 'ranged', color: '#f2f0d0', text: '15% chance to deal double damage' },
  regeneration: { name: 'BLOOD RUNE', family: 'melee', color: '#ff9b52', text: 'regenerate 2 vitality each second' },
  ward: { name: 'WARD RUNE', family: 'ranged', color: '#9fd6ff', text: 'extend damage invulnerability' },
  magnet: { name: 'GRAVITY RUNE', family: 'ranged', color: '#63d1c2', text: 'collect ranged nodes from farther away' },
  vitality: { name: 'IRON RUNE', family: 'melee', color: '#b9c8c2', text: '+35 maximum vitality' }
};
const enemyTypes = {
  wisp: { color: '#63d1c2', r: 12, hp: 30, speed: 54, damage: 7, essence: 10 },
  brute: { color: '#ed725c', r: 24, hp: 135, speed: 25, damage: 14, essence: 28 },
  charger: { color: '#edc968', r: 15, hp: 55, speed: 105, damage: 11, essence: 18 },
  splitter: { color: '#a98cff', r: 17, hp: 75, speed: 42, damage: 8, essence: 20 },
  leech: { color: '#ff9b52', r: 13, hp: 42, speed: 68, damage: 9, essence: 16 },
  oracle: { color: '#9fd6ff', r: 18, hp: 68, speed: 28, damage: 12, essence: 24 },
  regent: { color: '#f2f0d0', r: 34, hp: 520, speed: 19, damage: 28, essence: 140 }
};
let player;
let enemies = [];
let projectiles = [];
let enemyProjectiles = [];
let nodes = [];
let particles = [];
let equipped = [];
let weaponFamily = null;
let weaponRanks = {};
let level = 1;
let essence = 0;
let wave = 1;
let running = false;
let lastTime = 0;
let spawnTimer = 0;
let weaponTimers = {};
let invulnerable = 0;
let meleeFlash = 0;
let meleeAngle = 0;
let pickupRange = 34;
let damageMultiplier = 1;
let cooldownMultiplier = 1;
let masteryMultiplier = 1;
let criticalChance = 0;
let regeneration = 0;
let wardDuration = .7;
const arenaMarks = Array.from({ length: 26 }, () => ({ x: Math.random(), y: Math.random(), r: 18 + Math.random() * 42, alpha: .04 + Math.random() * .08 }));

function resize() {
  const ratio = window.devicePixelRatio || 1;
  canvas.width = frame.clientWidth * ratio;
  canvas.height = frame.clientHeight * ratio;
  canvas.style.height = `${frame.clientHeight}px`;
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
}
function distance(a, b) { return Math.hypot(a.x - b.x, a.y - b.y); }
function nearestEnemy() { return enemies.reduce((nearest, enemy) => !nearest || distance(enemy, player) < distance(nearest, player) ? enemy : nearest, null); }
function ascensionThreshold() { return 240 + (level - 1) * 190; }
function reset() {
  resize(); level = 1; essence = 0; wave = 1; equipped = []; weaponRanks = {}; weaponFamily = null; enemies = []; projectiles = []; enemyProjectiles = []; nodes = []; particles = []; weaponTimers = {}; invulnerable = 0; spawnTimer = 0; pickupRange = 34; damageMultiplier = 1; cooldownMultiplier = 1; masteryMultiplier = 1; criticalChance = 0; regeneration = 0; wardDuration = .7; meleeFlash = 0;
  player = { x: frame.clientWidth / 2, y: frame.clientHeight / 2, r: 16, hp: 85, maxHp: 85, speed: 220, damage: 22 };
  nodes.push({ x: player.x + 72, y: player.y, r: 17, type: Math.random() < .5 ? 'blade' : 'bolt', life: 40 });
  startOverlay.classList.add('hidden'); deathOverlay.classList.add('hidden'); levelOverlay.classList.add('hidden'); running = true; statusValue.textContent = 'AUTO-CAST ONLINE / CLAIM YOUR CROWN'; updateHud();
}
function updateHud() {
  levelValue.textContent = String(level).padStart(2, '0'); essenceValue.textContent = String(essence).padStart(3, '0'); waveValue.textContent = `0${wave} / 05`; healthBar.style.width = `${Math.max(0, player.hp / player.maxHp * 100)}%`;
  const weaponIds = equipped.filter(id => weapons[id]);
  nodePills.innerHTML = equipped.length ? equipped.map(id => { const item = weapons[id] || nodeUpgrades[id]; const rank = weapons[id] ? ` · RANK ${weaponRanks[id] || 1}` : ''; return `<span class="node-pill" style="border-color:${item.color};color:${item.color}">${item.name}${rank}</span>`; }).join('') : '<span class="empty-pill">NONE</span>';
  pathBadge.textContent = weaponFamily ? `${weaponFamily.toUpperCase()} PATH · ${weaponIds.length}/${maxWeapons}` : 'UNARMED · 0/5';
  const ready = !weaponIds.length || weaponIds.some(id => (weaponTimers[id] || 0) <= 0); cooldownValue.textContent = !weaponIds.length ? 'UNARMED' : ready ? 'READY' : `${Math.min(...weaponIds.map(id => weaponTimers[id])).toFixed(1)}s`;
}
function spawnEnemy() {
  const side = Math.floor(Math.random() * 4); const w = frame.clientWidth; const h = frame.clientHeight;
  const x = side % 2 ? Math.random() * w : side === 0 ? -35 : w + 35; const y = side % 2 ? side === 1 ? -35 : h + 35 : Math.random() * h;
  const roll = Math.random(); const type = wave >= 5 && roll < .08 ? 'regent' : roll < .16 ? 'brute' : roll < .3 ? 'charger' : roll < .44 ? 'splitter' : roll < .58 ? 'leech' : roll < .72 ? 'oracle' : 'wisp'; const base = enemyTypes[type];
  enemies.push({ x, y, type, r: base.r, hp: base.hp + wave * 14, maxHp: base.hp + wave * 14, speed: base.speed + wave * 4, damage: base.damage, essence: base.essence, shotTimer: 1.5 });
}
function spawnNode() { const weaponIds = Object.keys(weapons).filter(id => !equipped.includes(id) && equipped.filter(item => weapons[item]).length < maxWeapons && (!weaponFamily || weapons[id].family === weaponFamily)); const upgradeIds = Object.keys(nodeUpgrades).filter(id => !equipped.includes(id) && (!weaponFamily || nodeUpgrades[id].family === weaponFamily)); const duplicateIds = equipped.filter(id => weapons[id]); const ids = !weaponFamily ? weaponIds : Math.random() < .35 ? duplicateIds : [...weaponIds, ...upgradeIds]; if (!ids.length) return; const type = ids[Math.floor(Math.random() * ids.length)]; nodes.push({ x: 70 + Math.random() * (frame.clientWidth - 140), y: 70 + Math.random() * (frame.clientHeight - 140), r: 17, type, life: 25 }); }
function addParticles(x, y, color, amount = 5) { for (let i = 0; i < amount; i++) particles.push({ x, y, vx: (Math.random() - .5) * 150, vy: (Math.random() - .5) * 150, life: .45, color }); }
function weaponPower(id) {
  let multiplier = 1;
  if (id === 'bolt' && equipped.includes('blade')) multiplier += .35;
  if (id === 'nova' && equipped.includes('chain')) multiplier += .3;
  if (id === 'meteor' && equipped.includes('crown')) multiplier += .4;
  const critical = Math.random() < criticalChance ? 2 : 1;
  return player.damage * damageMultiplier * masteryMultiplier * multiplier * critical * (weaponRanks[id] || 1) ** .35;
}
function fireWeapon(id, target) {
  const weapon = weapons[id]; weaponTimers[id] = weapon.cooldown * cooldownMultiplier; const angle = Math.atan2(target.y - player.y, target.x - player.x); const power = player.damage * damageMultiplier;
  if (id === 'blade') { meleeAngle = angle; meleeFlash = .2; enemies.filter(enemy => distance(enemy, player) < 110).forEach(enemy => enemy.hp -= weaponPower(id) * 1.4); addParticles(player.x + Math.cos(angle) * 45, player.y + Math.sin(angle) * 45, weapon.color, 12); }
  else if (id === 'nova') { enemies.filter(enemy => distance(enemy, player) < 150).forEach(enemy => { enemy.hp -= weaponPower(id) * 1.25; enemy.x += Math.cos(angle) * 20; enemy.y += Math.sin(angle) * 20; }); addParticles(player.x, player.y, weapon.color, 20); }
  else if (id === 'chain') { let current = target; for (let i = 0; i < 3 && current; i++) { current.hp -= weaponPower(id) * 1.1; addParticles(current.x, current.y, weapon.color, 4); current = enemies.find(enemy => enemy !== current && distance(enemy, current) < 130 && enemy.hp > 0); } }
  else if (id === 'meteor') projectiles.push({ x: target.x, y: target.y, r: 42, life: .5, damage: power * 2.5, color: weapon.color, weapon: id, impact: true });
  else if (id === 'storm') enemies.filter(enemy => distance(enemy, target) < 180).slice(0, 4).forEach(enemy => { enemy.hp -= power * 1.1; addParticles(enemy.x, enemy.y, weapon.color, 5); });
  else projectiles.push({ x: player.x, y: player.y, vx: Math.cos(angle) * 560, vy: Math.sin(angle) * 560, r: id === 'venom' ? 9 : 7, life: 1.4, damage: id === 'frost' ? power * .9 : power, color: weapon.color, weapon: id, pierce: equipped.includes('blade'), slow: id === 'frost', poison: id === 'venom' });
}
function autoCast(dt) { const target = nearestEnemy(); if (!target) return; equipped.filter(id => weapons[id]).forEach(id => { weaponTimers[id] = Math.max(0, (weaponTimers[id] || 0) - dt); if (weaponTimers[id] === 0 && (id !== 'blade' || distance(target, player) <= 110)) fireWeapon(id, target); }); }
function damagePlayer(amount) { if (invulnerable > 0) return; invulnerable = wardDuration; player.hp -= amount; addParticles(player.x, player.y, '#ed725c', 10); if (player.hp <= 0) { running = false; deathOverlay.classList.remove('hidden'); document.querySelector('#deathCopy').textContent = `The vessel reached rank ${String(level).padStart(2, '0')} with ${essence} essence.`; } }
function collectNode(node) { const isWeapon = Boolean(weapons[node.type]); if (isWeapon) { if (!weaponFamily) weaponFamily = weapons[node.type].family; weaponRanks[node.type] = (weaponRanks[node.type] || 0) + 1; if (!equipped.includes(node.type) && equipped.filter(id => weapons[id]).length < maxWeapons) equipped.push(node.type); } else equipped.push(node.type); nodes = nodes.filter(item => item !== node); const item = weapons[node.type] || nodeUpgrades[node.type]; if (nodeUpgrades[node.type]) applyUpgrade(node.type); statusValue.textContent = `${item.name} ${isWeapon && weaponRanks[node.type] > 1 ? `RANK ${weaponRanks[node.type]}` : 'CLAIMED'} / ${weaponFamily ? weaponFamily.toUpperCase() : 'BUILD'} PATH`; addParticles(node.x, node.y, item.color, 15); updateHud(); }
function applyUpgrade(id) { if (id === 'damage') damageMultiplier *= 1.25; if (id === 'haste') cooldownMultiplier *= .82; if (id === 'vitality') { player.maxHp += 35; player.hp = player.maxHp; } if (id === 'magnet') pickupRange += 20; if (id === 'mastery') masteryMultiplier *= 1.18; if (id === 'critical') criticalChance += .15; if (id === 'regeneration') regeneration += 2; if (id === 'ward') wardDuration += .35; }
function offerUpgrade() {
  running = false; level++; const weaponChoices = Object.keys(weapons).filter(id => !equipped.includes(id) && weapons[id].family === weaponFamily).sort(() => Math.random() - .5).slice(0, Math.max(0, maxWeapons - equipped.filter(id => weapons[id]).length)); const compatibleUpgrades = Object.keys(upgradeTypes).filter(id => upgradeTypes[id].family === weaponFamily); const upgradeChoice = compatibleUpgrades[Math.floor(Math.random() * compatibleUpgrades.length)];
  const options = [...weaponChoices.map(id => ({ id, weapon: true })), { id: upgradeChoice, weapon: false }];
  choices.innerHTML = options.map(option => { const item = option.weapon ? weapons[option.id] : upgradeTypes[option.id]; return `<button class="upgrade-card" data-id="${option.id}" data-weapon="${option.weapon}" style="border-color:${item.color}"><b>${option.weapon ? item.name + ' NODE' : 'ASCENSION UPGRADE'}</b><strong>${option.weapon ? item.name : item.name}</strong><span>${item.text}. Choose carefully; your build will auto-cast every equipped weapon.</span></button>`; }).join('');
  choices.querySelectorAll('button').forEach(button => button.addEventListener('click', () => { if (button.dataset.weapon === 'true') equipped.push(button.dataset.id); else applyUpgrade(button.dataset.id); levelOverlay.classList.add('hidden'); running = true; statusValue.textContent = 'ASCENSION CONTINUES / BUILD EVOLVED'; updateHud(); })); levelOverlay.classList.remove('hidden');
}
function update(dt) {
  if (!running) return; let dx = (keys.has('d') || keys.has('arrowright')) - (keys.has('a') || keys.has('arrowleft')); let dy = (keys.has('s') || keys.has('arrowdown')) - (keys.has('w') || keys.has('arrowup')); const magnitude = Math.hypot(dx, dy) || 1;
  player.x = Math.max(player.r, Math.min(frame.clientWidth - player.r, player.x + dx / magnitude * player.speed * dt)); player.y = Math.max(player.r, Math.min(frame.clientHeight - player.r, player.y + dy / magnitude * player.speed * dt)); invulnerable = Math.max(0, invulnerable - dt); meleeFlash = Math.max(0, meleeFlash - dt); spawnTimer -= dt;
  if (spawnTimer <= 0) { spawnEnemy(); spawnTimer = Math.max(.18, .9 - wave * .12); } if (Math.random() < dt * .12 && nodes.length < 4) spawnNode(); player.hp = Math.min(player.maxHp, player.hp + regeneration * dt); autoCast(dt);
  enemies.forEach(enemy => { const angle = Math.atan2(player.y - enemy.y, player.x - enemy.x); const separation = enemy.type === 'oracle' && distance(enemy, player) < 230 ? -1 : 1; const slow = enemy.slow > 0 ? .45 : 1; enemy.slow = Math.max(0, (enemy.slow || 0) - dt); enemy.poison = Math.max(0, (enemy.poison || 0) - dt); enemy.hp -= enemy.poison > 0 ? dt * 7 : 0; enemy.x += Math.cos(angle) * enemy.speed * separation * slow * dt; enemy.y += Math.sin(angle) * enemy.speed * separation * slow * dt; if (enemy.type === 'leech' && Math.random() < dt * .3) player.hp = Math.max(1, player.hp - .7); if (distance(enemy, player) < enemy.r + player.r) damagePlayer(enemy.damage * dt * 1.25); if (enemy.type === 'oracle') { enemy.shotTimer -= dt; if (enemy.shotTimer <= 0) { enemy.shotTimer = 2.4; enemyProjectiles.push({ x: enemy.x, y: enemy.y, vx: Math.cos(angle) * 180, vy: Math.sin(angle) * 180, r: 7, damage: 12, life: 3, color: '#9fd6ff' }); } } if (enemy.type === 'splitter' && Math.random() < dt * .05 && enemies.length < 22) enemies.push({ ...enemy, type: 'wisp', r: 10, hp: 26 + wave * 4, maxHp: 26 + wave * 4, speed: 70 + wave * 3, x: enemy.x + 20, y: enemy.y + 20 }); });
  projectiles.forEach(projectile => { if (projectile.impact) { projectile.life -= dt; if (projectile.life < .35) enemies.filter(enemy => distance(enemy, projectile) < projectile.r).forEach(enemy => enemy.hp -= projectile.damage * dt * 3); } else { projectile.x += projectile.vx * dt; projectile.y += projectile.vy * dt; projectile.life -= dt; enemies.forEach(enemy => { if (distance(enemy, projectile) < enemy.r + projectile.r) { enemy.hp -= projectile.damage; if (projectile.slow) enemy.slow = 1.8; if (projectile.poison) enemy.poison = 3; if (!projectile.pierce) projectile.life = 0; addParticles(enemy.x, enemy.y, projectile.color, 4); } }); } });
  projectiles = projectiles.filter(projectile => projectile.life > 0); enemyProjectiles.forEach(projectile => { projectile.x += projectile.vx * dt; projectile.y += projectile.vy * dt; projectile.life -= dt; if (distance(projectile, player) < projectile.r + player.r) { damagePlayer(projectile.damage); projectile.life = 0; } }); enemyProjectiles = enemyProjectiles.filter(projectile => projectile.life > 0); enemies = enemies.filter(enemy => { if (enemy.hp <= 0) { essence += enemy.essence; addParticles(enemy.x, enemy.y, enemyTypes[enemy.type].color, 8); if (essence >= ascensionThreshold()) offerUpgrade(); return false; } return true; });
  nodes.forEach(node => { node.life -= dt; if (distance(node, player) < node.r + pickupRange) collectNode(node); }); nodes = nodes.filter(node => node.life > 0); particles.forEach(particle => { particle.x += particle.vx * dt; particle.y += particle.vy * dt; particle.life -= dt; }); particles = particles.filter(particle => particle.life > 0); if (enemies.length > 10 + wave * 3) wave = Math.min(5, wave + 1); updateHud();
}
function drawEquippedWeapons() {
  if (!player || !equipped.length) return;
  ctx.save(); ctx.translate(player.x, player.y);
  const equippedWeapons = equipped.filter(id => weapons[id]);
  equippedWeapons.forEach((id, index) => {
    const weapon = weapons[id]; const orbitAngle = (index / equippedWeapons.length) * Math.PI * 2 - Math.PI / 2; const angle = id === 'blade' && meleeFlash > 0 ? meleeAngle - 1.05 + (1 - meleeFlash / .2) * 2.1 : orbitAngle; const radius = id === 'blade' && meleeFlash > 0 ? 18 : 39 + Math.min(index, 3) * 5;
    const x = Math.cos(angle) * radius; const y = Math.sin(angle) * radius;
    ctx.save(); ctx.translate(x, y); ctx.rotate(angle + Math.PI / 2); ctx.strokeStyle = weapon.color; ctx.fillStyle = `${weapon.color}cc`; ctx.lineWidth = 3;
    if (id === 'blade') { ctx.beginPath(); ctx.moveTo(-6, 10); ctx.lineTo(0, -52); ctx.lineTo(6, 10); ctx.closePath(); ctx.fillStyle = '#dbe6df'; ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.moveTo(-13, 9); ctx.lineTo(13, 9); ctx.strokeStyle = '#edc968'; ctx.lineWidth = 5; ctx.stroke(); ctx.beginPath(); ctx.moveTo(-4, 10); ctx.lineTo(4, 10); ctx.strokeStyle = '#7d9693'; ctx.lineWidth = 4; ctx.stroke(); if (meleeFlash > 0) { ctx.beginPath(); ctx.arc(0, 0, 58, -1.05, 1.05); ctx.strokeStyle = '#fff1b0'; ctx.lineWidth = 3; ctx.globalAlpha = meleeFlash / .2; ctx.stroke(); } }
    else if (id === 'bolt') { ctx.beginPath(); ctx.moveTo(0, -16); ctx.lineTo(7, 11); ctx.lineTo(0, 7); ctx.lineTo(-7, 11); ctx.closePath(); ctx.fill(); ctx.stroke(); }
    else if (id === 'nova') { ctx.beginPath(); ctx.arc(0, 0, 12, 0, Math.PI * 2); ctx.stroke(); ctx.beginPath(); ctx.arc(0, 0, 5, 0, Math.PI * 2); ctx.fill(); }
    else if (id === 'chain') { ctx.beginPath(); ctx.arc(0, -7, 7, 0, Math.PI * 2); ctx.arc(0, 8, 7, 0, Math.PI * 2); ctx.stroke(); }
    else if (id === 'frost') { ctx.beginPath(); ctx.moveTo(0, -17); ctx.lineTo(8, 0); ctx.lineTo(0, 17); ctx.lineTo(-8, 0); ctx.closePath(); ctx.fill(); ctx.stroke(); }
    else if (id === 'venom') { ctx.beginPath(); ctx.arc(0, 0, 11, 0, Math.PI * 2); ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.moveTo(-5, -6); ctx.lineTo(0, 7); ctx.lineTo(5, -6); ctx.stroke(); }
    else if (id === 'storm') { ctx.beginPath(); ctx.moveTo(5, -17); ctx.lineTo(-4, -3); ctx.lineTo(3, -3); ctx.lineTo(-6, 17); ctx.lineTo(7, 1); ctx.lineTo(0, 1); ctx.closePath(); ctx.fill(); ctx.stroke(); }
    else { ctx.beginPath(); ctx.moveTo(0, -17); ctx.lineTo(9, 6); ctx.lineTo(0, 14); ctx.lineTo(-9, 6); ctx.closePath(); ctx.fill(); ctx.stroke(); }
    ctx.restore();
  }); ctx.restore();
}
function drawMonster(enemy, type) {
  ctx.save(); ctx.translate(enemy.x, enemy.y); ctx.rotate(Math.atan2(player.y - enemy.y, player.x - enemy.x));
  ctx.fillStyle = '#0b111d'; ctx.strokeStyle = type.color; ctx.lineWidth = enemy.type === 'regent' ? 4 : 3;
  if (enemy.type === 'brute' || enemy.type === 'regent') { ctx.beginPath(); ctx.roundRect(-enemy.r, -enemy.r * .8, enemy.r * 2, enemy.r * 1.6, 9); ctx.fill(); ctx.stroke(); ctx.fillStyle = type.color; ctx.beginPath(); ctx.moveTo(-enemy.r * .7, -enemy.r * .7); ctx.lineTo(-enemy.r * .35, -enemy.r - 8); ctx.lineTo(0, -enemy.r * .7); ctx.lineTo(enemy.r * .35, -enemy.r - 8); ctx.lineTo(enemy.r * .7, -enemy.r * .7); ctx.fill(); }
  else if (enemy.type === 'charger') { ctx.beginPath(); ctx.moveTo(enemy.r + 8, 0); ctx.lineTo(-enemy.r, -enemy.r); ctx.lineTo(-enemy.r * .6, 0); ctx.lineTo(-enemy.r, enemy.r); ctx.closePath(); ctx.fill(); ctx.stroke(); }
  else if (enemy.type === 'splitter') { ctx.beginPath(); ctx.arc(0, 0, enemy.r, 0, Math.PI * 2); ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.moveTo(-enemy.r, 0); ctx.lineTo(enemy.r, 0); ctx.stroke(); }
  else if (enemy.type === 'leech') { ctx.beginPath(); ctx.ellipse(0, 0, enemy.r * 1.35, enemy.r * .7, 0, 0, Math.PI * 2); ctx.fill(); ctx.stroke(); for (let i = -1; i <= 1; i++) { ctx.beginPath(); ctx.arc(i * 8, 0, 3, 0, Math.PI * 2); ctx.fillStyle = type.color; ctx.fill(); } }
  else { ctx.beginPath(); ctx.moveTo(0, -enemy.r - 5); ctx.lineTo(enemy.r, 0); ctx.lineTo(0, enemy.r + 5); ctx.lineTo(-enemy.r, 0); ctx.closePath(); ctx.fill(); ctx.stroke(); }
  ctx.fillStyle = type.color; ctx.fillRect(enemy.r * .15, -5, 5, 5); ctx.fillRect(enemy.r * .15, 1, 5, 5); ctx.restore();
}
function draw() {
  const w = frame.clientWidth; const h = frame.clientHeight; ctx.clearRect(0, 0, w, h);
  if (player && meleeFlash > 0) { ctx.save(); ctx.translate(player.x, player.y); ctx.rotate(meleeAngle); ctx.beginPath(); ctx.arc(0, 0, 82, -.95, .95); ctx.strokeStyle = '#edc968'; ctx.lineWidth = 10; ctx.globalAlpha = meleeFlash / .2; ctx.stroke(); ctx.restore(); }
  const floor = ctx.createRadialGradient(w * .5, h * .45, 40, w * .5, h * .5, Math.max(w, h) * .7); floor.addColorStop(0, '#293b60'); floor.addColorStop(.55, '#172640'); floor.addColorStop(1, '#091321'); ctx.fillStyle = floor; ctx.fillRect(0, 0, w, h);
  arenaMarks.forEach(mark => { ctx.beginPath(); ctx.arc(mark.x * w, mark.y * h, mark.r, 0, Math.PI * 2); ctx.fillStyle = `rgba(99, 209, 194, ${mark.alpha})`; ctx.fill(); });
  ctx.strokeStyle = '#ffffff0b';
  for (let x = 0; x < w; x += 48) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke(); }
  for (let y = 0; y < h; y += 48) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); }
  nodes.forEach(node => { const item = weapons[node.type] || nodeUpgrades[node.type]; const pulse = 34 + Math.sin(Date.now() / 160) * 6; ctx.beginPath(); ctx.ellipse(node.x, node.y + 20, 27, 9, 0, 0, Math.PI * 2); ctx.fillStyle = '#0008'; ctx.fill(); ctx.beginPath(); ctx.arc(node.x, node.y, pulse, 0, Math.PI * 2); ctx.fillStyle = `${item.color}20`; ctx.fill(); ctx.beginPath(); ctx.moveTo(node.x, node.y - 23); ctx.lineTo(node.x + 22, node.y); ctx.lineTo(node.x, node.y + 23); ctx.lineTo(node.x - 22, node.y); ctx.closePath(); const relic = ctx.createLinearGradient(node.x - 18, node.y - 18, node.x + 18, node.y + 18); relic.addColorStop(0, '#ffffff55'); relic.addColorStop(.25, item.color); relic.addColorStop(1, '#101f25'); ctx.fillStyle = relic; ctx.fill(); ctx.strokeStyle = item.color; ctx.lineWidth = 3; ctx.stroke(); ctx.beginPath(); ctx.arc(node.x, node.y, 8, 0, Math.PI * 2); ctx.fillStyle = item.color; ctx.fill(); ctx.fillStyle = '#edf2e9'; ctx.font = 'bold 10px "DM Mono"'; ctx.textAlign = 'center'; ctx.fillText(item.name[0], node.x, node.y + 4); ctx.fillStyle = '#0a1422dd'; ctx.fillRect(node.x - 67, node.y + 29, 134, 31); ctx.strokeStyle = `${item.color}aa`; ctx.lineWidth = 1; ctx.strokeRect(node.x - 67, node.y + 29, 134, 31); ctx.fillStyle = '#edf2e9'; ctx.font = 'bold 10px "DM Mono"'; ctx.fillText(item.name, node.x, node.y + 42); ctx.fillStyle = item.family === 'melee' ? '#ed725c' : item.family === 'ranged' ? '#edc968' : '#63d1c2'; ctx.font = '500 8px "DM Mono"'; ctx.fillText(item.family ? item.family.toUpperCase() : 'UPGRADE', node.x, node.y + 53); });
  projectiles.forEach(projectile => { ctx.save(); ctx.translate(projectile.x, projectile.y); ctx.rotate(Math.atan2(projectile.vy || 1, projectile.vx || 1)); ctx.fillStyle = `${projectile.color}dd`; ctx.strokeStyle = '#fff8'; ctx.lineWidth = 2; if (projectile.weapon === 'frost') { ctx.beginPath(); ctx.moveTo(0, -12); ctx.lineTo(7, 0); ctx.lineTo(0, 12); ctx.lineTo(-7, 0); ctx.closePath(); } else if (projectile.weapon === 'venom') { ctx.beginPath(); ctx.arc(0, 0, projectile.r, 0, Math.PI * 2); } else if (projectile.weapon === 'bolt') { ctx.beginPath(); ctx.moveTo(10, 0); ctx.lineTo(-7, -6); ctx.lineTo(-3, 0); ctx.lineTo(-7, 6); ctx.closePath(); } else { ctx.beginPath(); ctx.arc(0, 0, projectile.r, 0, Math.PI * 2); } ctx.fill(); ctx.stroke(); ctx.restore(); }); enemyProjectiles.forEach(projectile => { ctx.beginPath(); ctx.arc(projectile.x, projectile.y, projectile.r + 5, 0, Math.PI * 2); ctx.fillStyle = '#9fd6ff33'; ctx.fill(); ctx.beginPath(); ctx.arc(projectile.x, projectile.y, projectile.r, 0, Math.PI * 2); ctx.fillStyle = projectile.color; ctx.fill(); });
  enemies.forEach(enemy => { const type = enemyTypes[enemy.type]; ctx.beginPath(); ctx.ellipse(enemy.x, enemy.y + enemy.r + 7, enemy.r * 1.15, enemy.r * .35, 0, 0, Math.PI * 2); ctx.fillStyle = '#0009'; ctx.fill(); drawMonster(enemy, type); ctx.fillStyle = '#ed725c'; ctx.fillRect(enemy.x - enemy.r, enemy.y - enemy.r - 9, enemy.r * 2 * Math.max(0, enemy.hp / enemy.maxHp), 4); });
  particles.forEach(particle => { ctx.globalAlpha = Math.max(0, particle.life * 2); ctx.beginPath(); ctx.arc(particle.x, particle.y, 3, 0, Math.PI * 2); ctx.fillStyle = particle.color; ctx.fill(); ctx.globalAlpha = 1; });
  if (player) { ctx.save(); ctx.translate(player.x, player.y); const limbMetal = ctx.createLinearGradient(-30, 0, 30, 30); limbMetal.addColorStop(0, '#e8f0e8'); limbMetal.addColorStop(.45, '#879b9b'); limbMetal.addColorStop(1, '#263744'); ctx.strokeStyle = '#edc968'; ctx.lineWidth = 5; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(-19, 2); ctx.lineTo(-34, 20); ctx.lineTo(-29, 35); ctx.moveTo(19, 2); ctx.lineTo(34, 20); ctx.lineTo(29, 35); ctx.stroke(); ctx.fillStyle = limbMetal; ctx.beginPath(); ctx.arc(-34, 20, 7, 0, Math.PI * 2); ctx.arc(34, 20, 7, 0, Math.PI * 2); ctx.fill(); ctx.stroke(); ctx.fillStyle = limbMetal; ctx.strokeStyle = '#edc968'; ctx.lineWidth = 3; ctx.beginPath(); ctx.roundRect(-15, 19, 11, 23, 5); ctx.roundRect(4, 19, 11, 23, 5); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#263744'; ctx.fillRect(-16, 38, 14, 6); ctx.fillRect(2, 38, 14, 6); ctx.restore(); }
  if (player) { ctx.globalAlpha = invulnerable > 0 && Math.floor(Date.now() / 80) % 2 ? .35 : 1; ctx.beginPath(); ctx.ellipse(player.x, player.y + 25, 31, 10, 0, 0, Math.PI * 2); ctx.fillStyle = '#000b'; ctx.fill(); ctx.save(); ctx.translate(player.x, player.y); const steel = ctx.createLinearGradient(-22, -40, 20, 25); steel.addColorStop(0, '#eef4ed'); steel.addColorStop(.35, '#9aaca9'); steel.addColorStop(.7, '#53656a'); steel.addColorStop(1, '#273743'); ctx.fillStyle = steel; ctx.strokeStyle = '#edc968'; ctx.lineWidth = 3; ctx.beginPath(); ctx.ellipse(-22, 5, 9, 13, -.25, 0, Math.PI * 2); ctx.ellipse(22, 5, 9, 13, .25, 0, Math.PI * 2); ctx.fill(); ctx.stroke(); ctx.beginPath(); ctx.roundRect(-20, -8, 40, 32, 8); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#27323e'; ctx.fillRect(-18, 1, 36, 7); ctx.strokeStyle = '#172326'; ctx.lineWidth = 2; for (let i = -12; i <= 12; i += 8) { ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, 8); ctx.stroke(); } ctx.beginPath(); ctx.moveTo(-20, -8); ctx.lineTo(-13, -29); ctx.lineTo(0, -39); ctx.lineTo(13, -29); ctx.lineTo(20, -8); ctx.closePath(); ctx.fillStyle = steel; ctx.fill(); ctx.strokeStyle = '#edc968'; ctx.lineWidth = 3; ctx.stroke(); ctx.beginPath(); ctx.moveTo(-11, -29); ctx.lineTo(0, -47); ctx.lineTo(11, -29); ctx.lineTo(0, -36); ctx.closePath(); ctx.fillStyle = '#edc968'; ctx.fill(); ctx.beginPath(); ctx.moveTo(0, -35); ctx.lineTo(22, -49); ctx.lineTo(14, -25); ctx.strokeStyle = '#ed725c'; ctx.lineWidth = 6; ctx.stroke(); ctx.fillStyle = '#edc968'; ctx.fillRect(-6, -20, 4, 8); ctx.fillRect(2, -20, 4, 8); ctx.beginPath(); ctx.arc(27, 9, 13, 0, Math.PI * 2); ctx.fillStyle = '#7d9693'; ctx.fill(); ctx.strokeStyle = '#edc968'; ctx.lineWidth = 3; ctx.stroke(); ctx.beginPath(); ctx.moveTo(37, 18); ctx.lineTo(48, 35); ctx.strokeStyle = '#aebbb2'; ctx.lineWidth = 5; ctx.stroke(); ctx.restore(); ctx.globalAlpha = 1; }
  drawEquippedWeapons();
}
canvas.addEventListener('mousemove', event => { const bounds = canvas.getBoundingClientRect(); mouse.x = event.clientX - bounds.left; mouse.y = event.clientY - bounds.top; });
window.addEventListener('keydown', event => keys.add(event.key.toLowerCase())); window.addEventListener('keyup', event => keys.delete(event.key.toLowerCase()));
document.querySelector('#startButton').addEventListener('click', reset); document.querySelector('#restartButton').addEventListener('click', reset); window.addEventListener('resize', resize);
document.querySelector('#restartGameButton').addEventListener('click', reset);
function loop(timestamp = 0) { const dt = Math.min(.05, (timestamp - lastTime) / 1000 || 0); lastTime = timestamp; update(dt); draw(); requestAnimationFrame(loop); }
resize(); loop();
