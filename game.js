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
const keys = new Set();
const mouse = { x: 0, y: 0 };
const weapons = {
  blade: { name: 'VOID BLADE', color: '#ed725c', text: 'slashes the nearest enemy', cooldown: .8 },
  bolt: { name: 'STAR BOLT', color: '#edc968', text: 'fires a piercing projectile', cooldown: .32 },
  nova: { name: 'GRAVITY NOVA', color: '#63d1c2', text: 'bursts around the vessel', cooldown: 1.5 },
  chain: { name: 'SOUL CHAIN', color: '#a98cff', text: 'jumps between nearby enemies', cooldown: 1.1 },
  meteor: { name: 'ROYAL METEOR', color: '#ff9b52', text: 'calls down a heavy impact', cooldown: 2.2 }
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
let level = 1;
let essence = 0;
let wave = 1;
let running = false;
let lastTime = 0;
let spawnTimer = 0;
let weaponTimers = {};
let invulnerable = 0;

function resize() {
  const ratio = window.devicePixelRatio || 1;
  canvas.width = frame.clientWidth * ratio;
  canvas.height = frame.clientHeight * ratio;
  canvas.style.height = `${frame.clientHeight}px`;
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
}
function distance(a, b) { return Math.hypot(a.x - b.x, a.y - b.y); }
function nearestEnemy() { return enemies.reduce((nearest, enemy) => !nearest || distance(enemy, player) < distance(nearest, player) ? enemy : nearest, null); }
function reset() {
  resize(); level = 1; essence = 0; wave = 1; equipped = ['bolt']; enemies = []; projectiles = []; enemyProjectiles = []; nodes = []; particles = []; weaponTimers = {}; invulnerable = 0; spawnTimer = 0;
  player = { x: frame.clientWidth / 2, y: frame.clientHeight / 2, r: 16, hp: 85, maxHp: 85, speed: 220, damage: 22 };
  startOverlay.classList.add('hidden'); deathOverlay.classList.add('hidden'); levelOverlay.classList.add('hidden'); running = true; statusValue.textContent = 'AUTO-CAST ONLINE / CLAIM YOUR CROWN'; updateHud();
}
function updateHud() {
  levelValue.textContent = String(level).padStart(2, '0'); essenceValue.textContent = String(essence).padStart(3, '0'); waveValue.textContent = `0${wave} / 05`; healthBar.style.width = `${Math.max(0, player.hp / player.maxHp * 100)}%`;
  nodePills.innerHTML = equipped.map(id => `<span class="node-pill" style="border-color:${weapons[id].color};color:${weapons[id].color}">${weapons[id].name}</span>`).join('');
  const ready = equipped.some(id => (weaponTimers[id] || 0) <= 0); cooldownValue.textContent = ready ? 'READY' : `${Math.min(...equipped.map(id => weaponTimers[id])).toFixed(1)}s`;
}
function spawnEnemy() {
  const side = Math.floor(Math.random() * 4); const w = frame.clientWidth; const h = frame.clientHeight;
  const x = side % 2 ? Math.random() * w : side === 0 ? -35 : w + 35; const y = side % 2 ? side === 1 ? -35 : h + 35 : Math.random() * h;
  const roll = Math.random(); const type = wave >= 5 && roll < .08 ? 'regent' : roll < .16 ? 'brute' : roll < .3 ? 'charger' : roll < .44 ? 'splitter' : roll < .58 ? 'leech' : roll < .72 ? 'oracle' : 'wisp'; const base = enemyTypes[type];
  enemies.push({ x, y, type, r: base.r, hp: base.hp + wave * 14, maxHp: base.hp + wave * 14, speed: base.speed + wave * 4, damage: base.damage, essence: base.essence, shotTimer: 1.5 });
}
function spawnNode() { const ids = Object.keys(weapons).filter(id => !equipped.includes(id)); if (!ids.length) return; const type = ids[Math.floor(Math.random() * ids.length)]; nodes.push({ x: 70 + Math.random() * (frame.clientWidth - 140), y: 70 + Math.random() * (frame.clientHeight - 140), r: 17, type, life: 25 }); }
function addParticles(x, y, color, amount = 5) { for (let i = 0; i < amount; i++) particles.push({ x, y, vx: (Math.random() - .5) * 150, vy: (Math.random() - .5) * 150, life: .45, color }); }
function weaponPower(id) {
  let multiplier = 1;
  if (id === 'bolt' && equipped.includes('blade')) multiplier += .35;
  if (id === 'nova' && equipped.includes('chain')) multiplier += .3;
  if (id === 'meteor' && equipped.includes('crown')) multiplier += .4;
  return player.damage * multiplier;
}
function fireWeapon(id, target) {
  const weapon = weapons[id]; weaponTimers[id] = weapon.cooldown; const angle = Math.atan2(target.y - player.y, target.x - player.x);
  if (id === 'blade') { enemies.filter(enemy => distance(enemy, player) < 86).forEach(enemy => enemy.hp -= weaponPower(id) * 1.4); addParticles(player.x + Math.cos(angle) * 45, player.y + Math.sin(angle) * 45, weapon.color, 12); }
  else if (id === 'nova') { enemies.filter(enemy => distance(enemy, player) < 150).forEach(enemy => { enemy.hp -= weaponPower(id) * 1.25; enemy.x += Math.cos(angle) * 20; enemy.y += Math.sin(angle) * 20; }); addParticles(player.x, player.y, weapon.color, 20); }
  else if (id === 'chain') { let current = target; for (let i = 0; i < 3 && current; i++) { current.hp -= weaponPower(id) * 1.1; addParticles(current.x, current.y, weapon.color, 4); current = enemies.find(enemy => enemy !== current && distance(enemy, current) < 130 && enemy.hp > 0); } }
  else if (id === 'meteor') projectiles.push({ x: target.x, y: target.y, r: 42, life: .5, damage: weaponPower(id) * 2.5, color: weapon.color, impact: true });
  else projectiles.push({ x: player.x, y: player.y, vx: Math.cos(angle) * 560, vy: Math.sin(angle) * 560, r: 7, life: 1.4, damage: weaponPower(id), color: weapon.color, pierce: equipped.includes('blade') });
}
function autoCast(dt) { const target = nearestEnemy(); if (!target) return; equipped.forEach(id => { weaponTimers[id] = Math.max(0, (weaponTimers[id] || 0) - dt); if (weaponTimers[id] === 0) fireWeapon(id, target); }); }
function damagePlayer(amount) { if (invulnerable > 0) return; invulnerable = .7; player.hp -= amount; addParticles(player.x, player.y, '#ed725c', 10); if (player.hp <= 0) { running = false; deathOverlay.classList.remove('hidden'); document.querySelector('#deathCopy').textContent = `The vessel reached rank ${String(level).padStart(2, '0')} with ${essence} essence.`; } }
function collectNode(node) { equipped.push(node.type); nodes = nodes.filter(item => item !== node); statusValue.textContent = `${weapons[node.type].name} NODE CLAIMED / AUTO-CAST ARMED`; addParticles(node.x, node.y, weapons[node.type].color, 15); updateHud(); }
function offerUpgrade() {
  running = false; level++; const available = Object.keys(weapons).sort(() => Math.random() - .5).slice(0, 3);
  choices.innerHTML = available.map(id => `<button class="upgrade-card" data-weapon="${id}" style="border-color:${weapons[id].color}"><b>${weapons[id].name} NODE</b><strong>${id === 'blade' ? 'Close dominion' : id === 'bolt' ? 'Star artillery' : id === 'nova' ? 'Gravity bloom' : id === 'chain' ? 'Soul binding' : 'Royal judgment'}</strong><span>${weapons[id].text}. Equip multiple weapons and let them auto-cast together.</span></button>`).join('');
  choices.querySelectorAll('button').forEach(button => button.addEventListener('click', () => { if (!equipped.includes(button.dataset.weapon)) equipped.push(button.dataset.weapon); levelOverlay.classList.add('hidden'); running = true; statusValue.textContent = 'ASCENSION CONTINUES / MULTI-CAST ONLINE'; updateHud(); })); levelOverlay.classList.remove('hidden');
}
function update(dt) {
  if (!running) return; let dx = (keys.has('d') || keys.has('arrowright')) - (keys.has('a') || keys.has('arrowleft')); let dy = (keys.has('s') || keys.has('arrowdown')) - (keys.has('w') || keys.has('arrowup')); const magnitude = Math.hypot(dx, dy) || 1;
  player.x = Math.max(player.r, Math.min(frame.clientWidth - player.r, player.x + dx / magnitude * player.speed * dt)); player.y = Math.max(player.r, Math.min(frame.clientHeight - player.r, player.y + dy / magnitude * player.speed * dt)); invulnerable = Math.max(0, invulnerable - dt); spawnTimer -= dt;
  if (spawnTimer <= 0) { spawnEnemy(); spawnTimer = Math.max(.18, .9 - wave * .12); } if (Math.random() < dt * .12 && nodes.length < 4) spawnNode(); autoCast(dt);
  enemies.forEach(enemy => { const angle = Math.atan2(player.y - enemy.y, player.x - enemy.x); const separation = enemy.type === 'oracle' && distance(enemy, player) < 230 ? -1 : 1; enemy.x += Math.cos(angle) * enemy.speed * separation * dt; enemy.y += Math.sin(angle) * enemy.speed * separation * dt; if (enemy.type === 'leech' && Math.random() < dt * .3) player.hp = Math.max(1, player.hp - .7); if (distance(enemy, player) < enemy.r + player.r) damagePlayer(enemy.damage * dt * 1.25); if (enemy.type === 'oracle') { enemy.shotTimer -= dt; if (enemy.shotTimer <= 0) { enemy.shotTimer = 2.4; enemyProjectiles.push({ x: enemy.x, y: enemy.y, vx: Math.cos(angle) * 180, vy: Math.sin(angle) * 180, r: 7, damage: 12, life: 3, color: '#9fd6ff' }); } } if (enemy.type === 'splitter' && Math.random() < dt * .05 && enemies.length < 22) enemies.push({ ...enemy, type: 'wisp', r: 10, hp: 26 + wave * 4, maxHp: 26 + wave * 4, speed: 70 + wave * 3, x: enemy.x + 20, y: enemy.y + 20 }); });
  projectiles.forEach(projectile => { if (projectile.impact) { projectile.life -= dt; if (projectile.life < .35) enemies.filter(enemy => distance(enemy, projectile) < projectile.r).forEach(enemy => enemy.hp -= projectile.damage * dt * 3); } else { projectile.x += projectile.vx * dt; projectile.y += projectile.vy * dt; projectile.life -= dt; enemies.forEach(enemy => { if (distance(enemy, projectile) < enemy.r + projectile.r) { enemy.hp -= projectile.damage; if (!projectile.pierce) projectile.life = 0; addParticles(enemy.x, enemy.y, projectile.color, 4); } }); } });
  projectiles = projectiles.filter(projectile => projectile.life > 0); enemyProjectiles.forEach(projectile => { projectile.x += projectile.vx * dt; projectile.y += projectile.vy * dt; projectile.life -= dt; if (distance(projectile, player) < projectile.r + player.r) { damagePlayer(projectile.damage); projectile.life = 0; } }); enemyProjectiles = enemyProjectiles.filter(projectile => projectile.life > 0); enemies = enemies.filter(enemy => { if (enemy.hp <= 0) { essence += enemy.essence; addParticles(enemy.x, enemy.y, enemyTypes[enemy.type].color, 8); if (essence >= level * 100) offerUpgrade(); return false; } return true; });
  nodes.forEach(node => { node.life -= dt; if (distance(node, player) < node.r + player.r) collectNode(node); }); nodes = nodes.filter(node => node.life > 0); particles.forEach(particle => { particle.x += particle.vx * dt; particle.y += particle.vy * dt; particle.life -= dt; }); particles = particles.filter(particle => particle.life > 0); if (enemies.length > 10 + wave * 3) wave = Math.min(5, wave + 1); updateHud();
}
function draw() {
  const w = frame.clientWidth; const h = frame.clientHeight; ctx.clearRect(0, 0, w, h); ctx.strokeStyle = '#ffffff0b';
  for (let x = 0; x < w; x += 48) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke(); }
  for (let y = 0; y < h; y += 48) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); }
  nodes.forEach(node => { const weapon = weapons[node.type]; const pulse = 34 + Math.sin(Date.now() / 160) * 6; ctx.beginPath(); ctx.arc(node.x, node.y, pulse, 0, Math.PI * 2); ctx.fillStyle = `${weapon.color}20`; ctx.fill(); ctx.beginPath(); ctx.moveTo(node.x, node.y - 18); ctx.lineTo(node.x + 18, node.y); ctx.lineTo(node.x, node.y + 18); ctx.lineTo(node.x - 18, node.y); ctx.closePath(); ctx.fillStyle = '#101f25'; ctx.fill(); ctx.strokeStyle = weapon.color; ctx.lineWidth = 3; ctx.stroke(); ctx.beginPath(); ctx.arc(node.x, node.y, 7, 0, Math.PI * 2); ctx.fillStyle = weapon.color; ctx.fill(); ctx.fillStyle = '#edf2e9'; ctx.font = 'bold 11px "DM Mono"'; ctx.textAlign = 'center'; ctx.fillText(weapon.name[0], node.x, node.y + 4); });
  projectiles.forEach(projectile => { ctx.beginPath(); ctx.arc(projectile.x, projectile.y, projectile.r, 0, Math.PI * 2); ctx.fillStyle = `${projectile.color}cc`; ctx.fill(); }); enemyProjectiles.forEach(projectile => { ctx.beginPath(); ctx.arc(projectile.x, projectile.y, projectile.r + 5, 0, Math.PI * 2); ctx.fillStyle = '#9fd6ff33'; ctx.fill(); ctx.beginPath(); ctx.arc(projectile.x, projectile.y, projectile.r, 0, Math.PI * 2); ctx.fillStyle = projectile.color; ctx.fill(); });
  enemies.forEach(enemy => { const type = enemyTypes[enemy.type]; ctx.save(); ctx.translate(enemy.x, enemy.y); ctx.rotate(Math.atan2(player.y - enemy.y, player.x - enemy.x)); ctx.beginPath(); ctx.moveTo(enemy.r + 7, 0); ctx.lineTo(0, enemy.r); ctx.lineTo(-enemy.r * .8, 0); ctx.lineTo(0, -enemy.r); ctx.closePath(); ctx.fillStyle = '#0b171d'; ctx.fill(); ctx.strokeStyle = type.color; ctx.lineWidth = enemy.type === 'regent' ? 4 : 3; ctx.stroke(); ctx.fillStyle = type.color; ctx.fillRect(enemy.r * .2, -5, 5, 5); ctx.fillRect(enemy.r * .2, 1, 5, 5); ctx.restore(); ctx.fillStyle = '#ed725c'; ctx.fillRect(enemy.x - enemy.r, enemy.y - enemy.r - 9, enemy.r * 2 * Math.max(0, enemy.hp / enemy.maxHp), 4); });
  particles.forEach(particle => { ctx.globalAlpha = Math.max(0, particle.life * 2); ctx.beginPath(); ctx.arc(particle.x, particle.y, 3, 0, Math.PI * 2); ctx.fillStyle = particle.color; ctx.fill(); ctx.globalAlpha = 1; });
  if (player) { ctx.globalAlpha = invulnerable > 0 && Math.floor(Date.now() / 80) % 2 ? .35 : 1; ctx.save(); ctx.translate(player.x, player.y); ctx.beginPath(); ctx.moveTo(0, -player.r - 13); ctx.lineTo(player.r + 9, -player.r + 2); ctx.lineTo(player.r - 2, player.r + 15); ctx.lineTo(-player.r - 2, player.r + 15); ctx.lineTo(-player.r - 9, -player.r + 2); ctx.closePath(); ctx.fillStyle = '#b9c8c2'; ctx.fill(); ctx.strokeStyle = '#edc968'; ctx.lineWidth = 3; ctx.stroke(); ctx.beginPath(); ctx.moveTo(-player.r - 6, -player.r - 8); ctx.lineTo(0, -player.r - 20); ctx.lineTo(player.r + 6, -player.r - 8); ctx.strokeStyle = '#edc968'; ctx.lineWidth = 4; ctx.stroke(); ctx.fillStyle = '#172326'; ctx.fillRect(-5, -3, 3, 7); ctx.fillRect(2, -3, 3, 7); ctx.restore(); ctx.globalAlpha = 1; }
}
canvas.addEventListener('mousemove', event => { const bounds = canvas.getBoundingClientRect(); mouse.x = event.clientX - bounds.left; mouse.y = event.clientY - bounds.top; });
window.addEventListener('keydown', event => keys.add(event.key.toLowerCase())); window.addEventListener('keyup', event => keys.delete(event.key.toLowerCase()));
document.querySelector('#startButton').addEventListener('click', reset); document.querySelector('#restartButton').addEventListener('click', reset); window.addEventListener('resize', resize);
function loop(timestamp = 0) { const dt = Math.min(.05, (timestamp - lastTime) / 1000 || 0); lastTime = timestamp; update(dt); draw(); requestAnimationFrame(loop); }
resize(); loop();
