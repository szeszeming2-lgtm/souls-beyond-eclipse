// North-up minimap drawn from the map data, with the player's arrow and the camera's view.

export function drawMinimap(canvas, game, viewYaw) {
  const g = game, ctx = canvas.getContext("2d");
  const W = canvas.width, H = canvas.height;
  const sx = W / (g.bounds.x1 - g.bounds.x0), sz = H / (g.bounds.z1 - g.bounds.z0);
  const m = (x, z) => [(x - g.bounds.x0) * sx, (z - g.bounds.z0) * sz];
  ctx.clearRect(0, 0, W, H);
  const colors = { building: "#7a7f92", landmark: "#d2b482", water: "#28507a", platform: "#6e645a", road: "#3a3c48" };
  for (const p of g.map.blockout) {
    const c = colors[p.role];
    if (!c) continue;
    const [x, z] = m(p.position[0], p.position[2]);
    ctx.save();
    ctx.translate(x, z);
    if (p.rotation_deg) ctx.rotate((p.rotation_deg[1] * Math.PI) / 180);
    ctx.fillStyle = c;
    if (p.shape === "cylinder") { ctx.beginPath(); ctx.arc(0, 0, (p.size[0] / 2) * sx, 0, Math.PI * 2); ctx.fill(); }
    else ctx.fillRect((-p.size[0] / 2) * sx, (-p.size[2] / 2) * sz, p.size[0] * sx, p.size[2] * sz);
    ctx.restore();
  }
  const dot = (x, z, r, c) => { const [a, b] = m(x, z); ctx.fillStyle = c; ctx.beginPath(); ctx.arc(a, b, r, 0, Math.PI * 2); ctx.fill(); };
  dot(g.hub.position[0], g.hub.position[2], 5, "#ffbe5a");
  for (const f of g.map.fast_travel) dot(f.position[0], f.position[2], 4, "#6ed2ff");
  const [ax, az] = m(g.arena.center[0], g.arena.center[2]);
  ctx.strokeStyle = "#e05068"; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(ax, az, g.arena.radius_studs * sx, 0, Math.PI * 2); ctx.stroke();
  for (const e of g.enemies) if (e.alive && e.isBoss) dot(e.x, e.z, 4, "#e05068");
  const p = g.player;
  if (!p) return;
  const [px, pz] = m(p.x, p.z);
  // camera view cone
  const fwd = Math.atan2(-Math.cos(viewYaw), -Math.sin(viewYaw));
  ctx.fillStyle = "#ffffff22";
  ctx.beginPath(); ctx.moveTo(px, pz); ctx.arc(px, pz, 26, fwd - 0.5, fwd + 0.5); ctx.closePath(); ctx.fill();
  ctx.save();
  ctx.translate(px, pz);
  ctx.rotate(Math.atan2(p.face.z, p.face.x) + Math.PI / 2);
  ctx.fillStyle = "#fff";
  ctx.beginPath(); ctx.moveTo(0, -7); ctx.lineTo(5, 5); ctx.lineTo(-5, 5); ctx.closePath(); ctx.fill();
  ctx.restore();
}
