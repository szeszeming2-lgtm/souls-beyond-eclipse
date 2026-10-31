// Third-person 3D view with a cel-shaded (toon) look, built with Three.js.
// Everything you see is PLACEHOLDER art made from simple shapes: the city comes straight from
// the map data (blockout), characters are built from capsules, spheres and boxes.

import * as THREE from "three";

const TELL = {
  none: { normal: 0xff8a3d, unblockable: 0xff2e4d },
  protanopia: { normal: 0xffd23f, unblockable: 0x3d7bff },
  deuteranopia: { normal: 0xffd23f, unblockable: 0x3d7bff },
  tritanopia: { normal: 0xff8a3d, unblockable: 0xdc28a0 },
};
const QUALITY = {
  low: { ratio: 0.75, shadows: false, lights: false, edges: false },
  medium: { ratio: 1, shadows: false, lights: true, edges: true },
  high: { ratio: 1.5, shadows: true, shadowSize: 1024, lights: true, edges: true },
  ultra: { ratio: 2, shadows: true, shadowSize: 2048, lights: true, edges: true },
};
const MIN_PITCH = 0.12, MAX_PITCH = 1.25, MIN_ZOOM = 7, MAX_ZOOM = 26;

function seeded(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 2 ** 32);
}

function canvasTexture(w, h, draw) {
  const c = document.createElement("canvas");
  c.width = w; c.height = h;
  draw(c.getContext("2d"), w, h);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export class Renderer3D {
  constructor(canvas, game, overlay) {
    this.game = game;
    this.canvas = canvas;
    this.overlay = overlay;
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: !matchMedia("(pointer: coarse)").matches, powerPreference: "high-performance" });
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x141428);
    this.scene.fog = new THREE.Fog(0x1e1a30, 110, 520);
    this.camera = new THREE.PerspectiveCamera(60, 1, 0.1, 2000);
    this.yaw = 0;
    this.pitch = 0.36;
    this.zoom = 15;
    this.lastCameraInput = -Infinity;
    this.raycaster = new THREE.Raycaster();
    this.tmp = new THREE.Vector3();
    this.models = new Map(); // enemy -> model
    this.tells = new Map(); // enemy -> telegraph group
    this.fxObjects = new Map(); // fx entry -> object
    this.labels = new Map(); // key -> DOM element
    this.occluders = [];
    this.lights = [];
    this.makeMaterials();
    this.buildLights();
    this.buildSky();
    this.buildWorld();
    this.buildScenery();
    this.buildPlayer();
    this.setQuality("auto");
    this.fps = { frames: 0, time: 0, slow: 0 };
    addEventListener("resize", () => this.resize());
    this.resize();
  }

  // ---------------------------------------------------------------- setup
  makeMaterials() {
    const steps = new Uint8Array([105, 105, 105, 255, 175, 175, 175, 255, 255, 255, 255, 255]);
    this.gradient = new THREE.DataTexture(steps, 3, 1, THREE.RGBAFormat);
    this.gradient.minFilter = this.gradient.magFilter = THREE.NearestFilter;
    this.gradient.needsUpdate = true;
    this.toonCache = new Map();
    this.outlineMat = new THREE.MeshBasicMaterial({ color: 0x06060a, side: THREE.BackSide });
    this.flashMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
    this.ghostMat = new THREE.MeshBasicMaterial({ color: 0x9fc4ff, transparent: true, opacity: 0.45 });
    this.shared = new Set([this.outlineMat, this.flashMat, this.ghostMat]);
    this.glowTex = canvasTexture(64, 64, (ctx, w) => {
      const g = ctx.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2);
      g.addColorStop(0, "rgba(255,255,255,1)"); g.addColorStop(0.35, "rgba(255,255,255,0.45)"); g.addColorStop(1, "rgba(255,255,255,0)");
      ctx.fillStyle = g; ctx.fillRect(0, 0, w, w);
    });
  }

  toon(color) {
    if (!this.toonCache.has(color)) {
      const mat = new THREE.MeshToonMaterial({ color, gradientMap: this.gradient });
      this.toonCache.set(color, mat);
      this.shared.add(mat);
    }
    return this.toonCache.get(color);
  }

  glow(color, size, opacity = 1) {
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.glowTex, color, transparent: true, opacity, blending: THREE.AdditiveBlending, depthWrite: false }));
    s.scale.setScalar(size);
    return s;
  }

  outline(mesh, thickness = 0.07) {
    const o = new THREE.Mesh(mesh.geometry, this.outlineMat);
    o.scale.setScalar(1 + thickness);
    mesh.add(o);
    return mesh;
  }

  buildLights() {
    this.scene.add(new THREE.HemisphereLight(0x9aa8e8, 0x4a3448, 1.9));
    this.scene.add(new THREE.AmbientLight(0x6a6080, 0.7));
    const moon = new THREE.DirectionalLight(0xd6dcff, 2.1);
    moon.position.set(-60, 140, 50);
    moon.shadow.camera.left = moon.shadow.camera.bottom = -70;
    moon.shadow.camera.right = moon.shadow.camera.top = 70;
    moon.shadow.camera.far = 400;
    moon.shadow.bias = -0.0005;
    this.scene.add(moon, moon.target);
    this.moon = moon;
  }

  buildSky() {
    // Gradient dome: warm glow at the horizon under the eclipse, deep blue overhead.
    const dome = canvasTexture(4, 256, (ctx, w, h) => {
      const g = ctx.createLinearGradient(0, 0, 0, h);
      g.addColorStop(0, "#070914"); g.addColorStop(0.35, "#141632"); g.addColorStop(0.47, "#3a2440"); g.addColorStop(0.5, "#5a3040"); g.addColorStop(0.53, "#1e1a30"); g.addColorStop(1, "#1e1a30");
      ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
    });
    this.sky = new THREE.Mesh(new THREE.SphereGeometry(1500, 32, 16), new THREE.MeshBasicMaterial({ map: dome, side: THREE.BackSide, fog: false, depthWrite: false }));
    this.sky.renderOrder = -1;
    this.scene.add(this.sky);
    // Stars
    const rand = seeded(7), pts = [];
    for (let i = 0; i < 700; i++) {
      const u = rand() * Math.PI * 2, v = 0.15 + rand() * 0.85;
      pts.push(Math.cos(u) * Math.sqrt(1 - v * v) * 1200, v * 1200, Math.sin(u) * Math.sqrt(1 - v * v) * 1200);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.Float32BufferAttribute(pts, 3));
    this.stars = new THREE.Points(geo, new THREE.PointsMaterial({ color: 0xdfe6ff, size: 2, sizeAttenuation: false, fog: false }));
    this.scene.add(this.stars);
    // The eclipse: a black sun with a burning corona
    const corona = canvasTexture(256, 256, (ctx, w) => {
      const g = ctx.createRadialGradient(w / 2, w / 2, w * 0.18, w / 2, w / 2, w / 2);
      g.addColorStop(0, "rgba(255,190,110,1)"); g.addColorStop(0.12, "rgba(255,140,60,0.8)"); g.addColorStop(0.45, "rgba(200,60,40,0.25)"); g.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = g; ctx.fillRect(0, 0, w, w);
      ctx.fillStyle = "#050307"; ctx.beginPath(); ctx.arc(w / 2, w / 2, w * 0.2, 0, Math.PI * 2); ctx.fill();
    });
    this.eclipse = new THREE.Sprite(new THREE.SpriteMaterial({ map: corona, fog: false, depthWrite: false, transparent: true }));
    this.eclipse.scale.setScalar(260);
    this.scene.add(this.eclipse);
  }

  windowTexture(seed) {
    const rand = seeded(seed);
    const tex = canvasTexture(64, 64, (ctx) => {
      ctx.fillStyle = "#5a6074"; ctx.fillRect(0, 0, 64, 64);
      for (let y = 6; y < 64; y += 16) for (let x = 6; x < 64; x += 14) {
        ctx.fillStyle = rand() > 0.45 ? "#ffd38a" : "#2a2d3a";
        ctx.fillRect(x, y, 7, 8);
      }
    });
    tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
    return tex;
  }

  buildWorld() {
    const g = this.game;
    this.world = new THREE.Group();
    this.scene.add(this.world);
    this.edges = [];
    const roofMat = this.toon(0x4a4f60);
    g.map.blockout.forEach((p, i) => {
      const [x, y, z] = p.position, [sx, sy, sz] = p.size;
      let mesh;
      if (p.shape === "cylinder") {
        mesh = new THREE.Mesh(new THREE.CylinderGeometry(sx / 2, sx / 2, sy, 48), this.toon(p.role === "platform" ? 0x4d4b57 : 0x8a8a92));
      } else if (p.role === "water") {
        mesh = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), new THREE.MeshPhongMaterial({ color: 0x1b3c66, transparent: true, opacity: 0.85, shininess: 90, specular: 0x88aaff }));
        this.water = mesh;
      } else if (p.role === "building") {
        const tex = this.windowTexture(i * 31 + 5);
        const side = (w, h) => { const t = tex.clone(); t.repeat.set(Math.max(1, w / 10), Math.max(1, h / 10)); t.needsUpdate = true; return new THREE.MeshToonMaterial({ map: t, gradientMap: this.gradient }); };
        mesh = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), [side(sz, sy), side(sz, sy), roofMat, roofMat, side(sx, sy), side(sx, sy)]);
        this.occluders.push(mesh);
      } else {
        const color = { ground: 0x2c2e3a, road: 0x2a2b34, landmark: 0xb4936a, platform: 0x5a4636, wall: 0x22242e, prop: 0x8c8c96, hazard: 0x8a3030, ramp: 0x6a6a74 }[p.role] ?? 0x777777;
        let mat = p.role === "wall" ? new THREE.MeshToonMaterial({ color, gradientMap: this.gradient, transparent: true, opacity: 0.0, depthWrite: false }) : this.toon(color);
        if (p.role === "ground") mat = this.texturedMat(this.pavingTexture(), sx / 6, sz / 6);
        else if (p.role === "platform" && /boardwalk/i.test(p.label || "")) mat = this.texturedMat(this.plankTexture(), sx / 8, sz / 8);
        else if (p.role === "platform") mat = this.texturedMat(this.pavingTexture("#6a6258", "#59524a"), sx / 4, sz / 4);
        mesh = new THREE.Mesh(new THREE.BoxGeometry(sx, sy, sz), mat);
        if (p.role === "landmark" && sy > 20) this.occluders.push(mesh);
      }
      mesh.position.set(x, y, z);
      if (p.rotation_deg) mesh.rotation.set(...p.rotation_deg.map((d) => (d * Math.PI) / 180));
      mesh.receiveShadow = true;
      mesh.castShadow = ["building", "landmark", "prop"].includes(p.role);
      mesh.visible = p.role !== "wall"; // invisible map edge
      this.world.add(mesh);
      if (["building", "landmark", "prop"].includes(p.role)) {
        const lines = new THREE.LineSegments(new THREE.EdgesGeometry(mesh.geometry), new THREE.LineBasicMaterial({ color: 0x0a0a10 }));
        mesh.add(lines);
        this.edges.push(lines);
      }
      if (p.label?.includes("Clocktower")) this.decorateClocktower(mesh, sx, sy);
      if (p.role === "road") {
        const lane = new THREE.Mesh(new THREE.PlaneGeometry(0.5, sz * 0.95), new THREE.MeshBasicMaterial({ color: 0x8a8a70 }));
        lane.rotation.x = -Math.PI / 2;
        lane.position.y = sy / 2 + 0.02;
        mesh.add(lane);
      }
    });
    // markers: hub, fast travel, boss arena, secrets
    const hub = g.hub;
    const ring = new THREE.Mesh(new THREE.RingGeometry(hub.radius_studs - 0.6, hub.radius_studs, 64), new THREE.MeshBasicMaterial({ color: 0xffbe5a, transparent: true, opacity: 0.35, side: THREE.DoubleSide }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(hub.position[0], g.groundHeight(hub.position[0], hub.position[2]) + 0.06, hub.position[2]);
    this.world.add(ring);
    const lantern = new THREE.Mesh(new THREE.SphereGeometry(1.1, 16, 12), new THREE.MeshBasicMaterial({ color: 0xffc070 }));
    lantern.position.set(hub.position[0], 7, hub.position[2]);
    lantern.add(this.glow(0xffa040, 14, 0.8));
    this.world.add(lantern);
    this.hubLantern = lantern;
    this.addLight(0xffa850, 2.5, 45, hub.position[0], 8, hub.position[2]);
    this.crystals = g.map.fast_travel.map((f) => {
      const c = new THREE.Mesh(new THREE.OctahedronGeometry(1.2), new THREE.MeshBasicMaterial({ color: 0x8fe0ff }));
      c.position.set(f.position[0], 3, f.position[2]);
      c.add(this.glow(0x6ed2ff, 8, 0.8));
      this.world.add(c);
      this.addLight(0x6ed2ff, 1.5, 22, f.position[0], 4, f.position[2]);
      return c;
    });
    const a = g.arena;
    const arenaRing = new THREE.Mesh(new THREE.RingGeometry(a.radius_studs - 0.8, a.radius_studs, 96), new THREE.MeshBasicMaterial({ color: 0xc83c50, transparent: true, opacity: 0.4, side: THREE.DoubleSide }));
    arenaRing.rotation.x = -Math.PI / 2;
    arenaRing.position.set(a.center[0], g.groundHeight(a.center[0], a.center[2]) + 0.06, a.center[2]);
    this.world.add(arenaRing);
    this.secrets = g.map.secrets.map((s) => {
      const m = new THREE.Mesh(new THREE.OctahedronGeometry(0.5), new THREE.MeshBasicMaterial({ color: 0xfff6c8 }));
      m.position.set(s.position[0], Math.min(s.position[1], 30) + 1.5, s.position[2]);
      m.add(this.glow(0xfff0b0, 4, 0.9));
      this.world.add(m);
      return { mesh: m, id: s.id };
    });
  }

  texturedMat(tex, rx, ry) {
    const t = tex.clone();
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(rx, ry);
    t.anisotropy = 4;
    t.needsUpdate = true;
    return new THREE.MeshToonMaterial({ map: t, gradientMap: this.gradient });
  }

  pavingTexture(base = "#4e5366", line = "#3c4050") {
    return canvasTexture(64, 64, (ctx) => {
      const rand = seeded(11);
      ctx.fillStyle = base; ctx.fillRect(0, 0, 64, 64);
      for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
        ctx.fillStyle = `rgba(255,255,255,${rand() * 0.05})`;
        ctx.fillRect(i * 16 + 1, j * 16 + 1, 14, 14);
      }
      ctx.fillStyle = line;
      for (let i = 0; i < 64; i += 16) { ctx.fillRect(i, 0, 1.5, 64); ctx.fillRect(0, i, 64, 1.5); }
    });
  }

  plankTexture() {
    return canvasTexture(64, 64, (ctx) => {
      const rand = seeded(23);
      for (let i = 0; i < 8; i++) {
        const v = 92 + Math.floor(rand() * 18);
        ctx.fillStyle = `rgb(${v},${Math.floor(v * 0.72)},${Math.floor(v * 0.5)})`;
        ctx.fillRect(0, i * 8, 64, 7);
        ctx.fillStyle = "#3a2a1e"; ctx.fillRect(Math.floor(rand() * 64), i * 8, 1.5, 7);
      }
    });
  }

  // Background only: a distant skyline outside the play area, and street lamps (no collision).
  buildScenery() {
    const g = this.game, b = g.bounds, rand = seeded(99);
    const mats = [0, 1, 2].map((k) => {
      const t = this.windowTexture(500 + k);
      t.repeat.set(2 + k, 4 + k);
      return new THREE.MeshToonMaterial({ map: t, gradientMap: this.gradient, color: 0xb0b4c8 });
    });
    const roof = this.toon(0x2e3240);
    const place = (x, z) => {
      const w = 20 + rand() * 35, d = 20 + rand() * 35, h = 30 + rand() * 110;
      const m = mats[Math.floor(rand() * 3)];
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), [m, m, roof, roof, m, m]);
      mesh.position.set(x, h / 2 - 1, z);
      this.world.add(mesh);
    };
    for (let x = b.x0 - 40; x <= b.x1 + 40; x += 48) {
      place(x + rand() * 20, b.z0 - 40 - rand() * 60); // north
      place(x + rand() * 20, b.z1 + 70 + rand() * 80); // across the harbor
    }
    for (let z = b.z0; z <= b.z1 - 60; z += 48) {
      place(b.x0 - 40 - rand() * 60, z + rand() * 20); // west
      place(b.x1 + 40 + rand() * 60, z + rand() * 20); // east
    }
    // far ground and sea so the edge of the map isn't a void
    const far = new THREE.Mesh(new THREE.PlaneGeometry(3000, 3000), this.toon(0x232334));
    far.rotation.x = -Math.PI / 2;
    far.position.y = -2.5;
    this.world.add(far);
    const sea = new THREE.Mesh(new THREE.PlaneGeometry(1400, 140), new THREE.MeshPhongMaterial({ color: 0x1b3c66, shininess: 80, specular: 0x6688cc }));
    sea.rotation.x = -Math.PI / 2;
    sea.position.set(0, -2.05, b.z1 - 10);
    this.world.add(sea);
    // street lamps
    const poleGeo = new THREE.CylinderGeometry(0.18, 0.25, 7, 6), poleMat = this.toon(0x1a1c24);
    const lamp = (x, z) => {
      const y = g.groundHeight(x, z);
      const pole = new THREE.Mesh(poleGeo, poleMat);
      pole.position.set(x, y + 3.5, z);
      const head = new THREE.Mesh(new THREE.SphereGeometry(0.45, 10, 8), new THREE.MeshBasicMaterial({ color: 0xffe2a8 }));
      head.position.y = 3.6;
      head.add(this.glow(0xffc070, 7, 0.75));
      pole.add(head);
      const pool = new THREE.Mesh(new THREE.CircleGeometry(5, 20), new THREE.MeshBasicMaterial({ color: 0xffb860, transparent: true, opacity: 0.12, depthWrite: false }));
      pool.rotation.x = -Math.PI / 2;
      pool.position.y = -3.45;
      pole.add(pool);
      this.world.add(pole);
    };
    const road = g.map.blockout.find((p) => p.role === "road");
    if (road) {
      const a = (road.rotation_deg?.[1] ?? 0) * Math.PI / 180;
      const along = { x: Math.sin(a), z: Math.cos(a) }, side = { x: Math.cos(a), z: -Math.sin(a) };
      for (let k = -road.size[2] / 2 + 10; k <= road.size[2] / 2 - 10; k += 30) {
        for (const s of [-1, 1]) lamp(road.position[0] + along.x * k + side.x * s * (road.size[0] / 2 + 2), road.position[2] + along.z * k + side.z * s * (road.size[0] / 2 + 2));
      }
    }
    const boardwalk = g.map.blockout.find((p) => /boardwalk/i.test(p.label || ""));
    if (boardwalk) {
      for (let x = boardwalk.position[0] - boardwalk.size[0] / 2 + 15; x < boardwalk.position[0] + boardwalk.size[0] / 2; x += 35) {
        lamp(x, boardwalk.position[2] + boardwalk.size[2] / 2 - 1.5);
      }
    }
  }

  decorateClocktower(mesh, sx, sy) {
    const face = canvasTexture(128, 128, (ctx, w) => {
      ctx.fillStyle = "#f6e6c4"; ctx.beginPath(); ctx.arc(w / 2, w / 2, w * 0.46, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = "#3a2a1a"; ctx.lineWidth = 6; ctx.lineCap = "round";
      ctx.beginPath(); ctx.moveTo(w / 2, w / 2); ctx.lineTo(w / 2, w * 0.14); ctx.stroke(); // 12
      ctx.beginPath(); ctx.moveTo(w / 2, w / 2); ctx.lineTo(w * 0.58, w * 0.3); ctx.stroke(); // :07
    });
    const mat = new THREE.MeshBasicMaterial({ map: face, transparent: true });
    for (let i = 0; i < 4; i++) {
      const plane = new THREE.Mesh(new THREE.PlaneGeometry(sx * 0.7, sx * 0.7), mat);
      const a = (i * Math.PI) / 2;
      plane.position.set(Math.sin(a) * (sx / 2 + 0.05), sy / 2 - sx * 0.6, Math.cos(a) * (sx / 2 + 0.05));
      plane.rotation.y = a;
      mesh.add(plane);
    }
    this.addLight(0xfff0d0, 1.5, 60, mesh.position.x, mesh.position.y + sy / 2 - sx * 0.6, mesh.position.z);
  }

  addLight(color, intensity, distance, x, y, z) {
    const l = new THREE.PointLight(color, intensity, distance, 1.2);
    l.position.set(x, y, z);
    this.scene.add(l);
    this.lights.push(l);
    return l;
  }

  // ---------------------------------------------------------------- characters
  shadowBlob(radius) {
    const m = new THREE.Mesh(new THREE.CircleGeometry(radius, 20), new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.35, depthWrite: false }));
    m.rotation.x = -Math.PI / 2;
    m.position.y = 0.05;
    return m;
  }

  buildPlayer() {
    const group = new THREE.Group();
    group.rotation.order = "YXZ";
    const body = this.outline(new THREE.Mesh(new THREE.CapsuleGeometry(0.75, 1.2, 6, 14), this.toon(0x2e3a59)));
    body.position.y = 1.35;
    const head = this.outline(new THREE.Mesh(new THREE.SphereGeometry(0.58, 18, 14), this.toon(0xd19a72)));
    head.position.y = 2.75;
    const hair = new THREE.Mesh(new THREE.SphereGeometry(0.64, 18, 10, 0, Math.PI * 2, 0, Math.PI * 0.55), this.toon(0x1b1b1f));
    hair.position.y = 2.82;
    hair.rotation.x = -0.25;
    const scarf = new THREE.Mesh(new THREE.TorusGeometry(0.62, 0.16, 8, 20), this.toon(0xf2a33a));
    scarf.rotation.x = Math.PI / 2;
    scarf.position.y = 2.25;
    const pivot = new THREE.Group();
    pivot.position.set(-0.75, 1.65, 0.2);
    const blade = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.22, 3.4), new THREE.MeshBasicMaterial({ color: 0xffc478 }));
    blade.position.z = 2.1;
    blade.add(this.glow(0xff9a40, 3.2, 0.5));
    const hilt = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.16, 0.9), this.toon(0x2d1e19));
    hilt.position.z = 0.1;
    const guard = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.32, 0.08, 12), this.toon(0xc49646));
    guard.rotation.x = Math.PI / 2;
    guard.position.z = 0.55;
    pivot.add(blade, hilt, guard);
    group.add(this.shadowBlob(1.3), body, head, hair, scarf, pivot);
    group.traverse((o) => { if (o.isMesh && o.material !== this.outlineMat) o.castShadow = true; });
    this.scene.add(group);
    this.aura = new THREE.PointLight(0xf2a33a, 2.2, 16, 1.2);
    this.aura.position.y = 3;
    group.add(this.aura);
    this.bossLight = new THREE.PointLight(0xffc878, 0, 34, 1.2);
    this.scene.add(this.bossLight);
    this.player = { group, body, head, pivot, blade, bodyMat: body.material };
    this.trail = null;
  }

  buildGloamling() {
    const group = new THREE.Group();
    const torso = new THREE.Group();
    const body = this.outline(new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), this.toon(0x2b2b36)));
    body.scale.set(1.1, 0.8, 1.6);
    body.position.y = 1.4;
    const headMesh = this.outline(new THREE.Mesh(new THREE.SphereGeometry(0.72, 14, 10), this.toon(0x24242e)));
    headMesh.position.set(0, 1.75, 1.45);
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.26, 10, 8), new THREE.MeshBasicMaterial({ color: 0xffa040 }));
    eye.position.set(0, 1.9, 2.08);
    eye.add(this.glow(0xff8c32, 2.4, 0.9));
    torso.add(body, headMesh, eye);
    const legGeo = new THREE.CylinderGeometry(0.16, 0.12, 1.2, 6);
    for (const [lx, lz] of [[-0.7, 0.8], [0.7, 0.8], [-0.7, -0.8], [0.7, -0.8]]) {
      const leg = new THREE.Mesh(legGeo, this.toon(0x1e1e26));
      leg.position.set(lx, 0.6, lz);
      group.add(leg);
    }
    group.add(this.shadowBlob(1.6), torso);
    group.traverse((o) => { if (o.isMesh && o.material !== this.outlineMat) o.castShadow = true; });
    return { group, torso, body, flashParts: [body, headMesh], baseMat: body.material };
  }

  buildLampeater() {
    const group = new THREE.Group();
    const dark = this.toon(0x1e1a26);
    const torso = new THREE.Group();
    torso.position.y = 9.5;
    const chest = this.outline(new THREE.Mesh(new THREE.BoxGeometry(5, 6, 3.4), dark), 0.04);
    const head = this.outline(new THREE.Mesh(new THREE.BoxGeometry(2.2, 1.8, 2.2), dark), 0.05);
    head.position.set(0, 4, 0.4);
    for (const ex of [-0.5, 0.5]) {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.28, 8, 6), new THREE.MeshBasicMaterial({ color: 0xff7840 }));
      eye.position.set(ex, 4.15, 1.55);
      eye.add(this.glow(0xff6020, 2, 0.9));
      torso.add(eye);
    }
    for (const [lx, ly] of [[-1.2, 1.2], [1.2, 1.2], [-1, -0.8], [1, -0.8]]) {
      const lamp = new THREE.Mesh(new THREE.SphereGeometry(0.62, 12, 10), new THREE.MeshBasicMaterial({ color: 0xffd682 }));
      lamp.position.set(lx, ly, 1.65);
      lamp.add(this.glow(0xffc060, 4, 0.8));
      torso.add(lamp);
    }
    const armGeo = new THREE.CylinderGeometry(0.45, 0.35, 8, 8);
    armGeo.translate(0, -4, 0);
    const arms = [-3.2, 3.2].map((ax) => {
      const arm = this.outline(new THREE.Mesh(armGeo, dark), 0.06);
      arm.position.set(ax, 2.5, 0.3);
      torso.add(arm);
      return arm;
    });
    torso.add(chest, head);
    const legGeo = new THREE.CylinderGeometry(0.6, 0.5, 7, 8);
    for (const lx of [-1.4, 1.4]) {
      const leg = this.outline(new THREE.Mesh(legGeo, dark), 0.05);
      leg.position.set(lx, 3.5, 0);
      group.add(leg);
    }
    group.add(this.shadowBlob(4.5), torso);
    group.traverse((o) => { if (o.isMesh && o.material !== this.outlineMat) o.castShadow = true; });
    return { group, torso, body: chest, arms, flashParts: [chest, head], baseMat: dark };
  }

  modelFor(e) {
    let m = this.models.get(e);
    if (!m) {
      m = e.def.id === "enm_lampeater" ? this.buildLampeater() : this.buildGloamling();
      m.group.rotation.order = "YXZ";
      m.burn = this.glow(0xff7a30, e.isBoss ? 14 : 5, 0.7);
      m.burn.position.y = e.isBoss ? 9 : 1.5;
      m.burn.visible = false;
      m.group.add(m.burn);
      this.scene.add(m.group);
      this.models.set(e, m);
    }
    return m;
  }

  // ---------------------------------------------------------------- telegraphs
  tellMesh(e) {
    const tell = e.tell, atk = tell.atk, area = atk.area;
    const palette = TELL[this.game.setting("colorblind")] || TELL.none;
    const color = tell.unblockable ? palette.unblockable : palette.normal;
    const r = area.radius_studs ?? atk.range_studs;
    const make = () => {
      let geo;
      if (area.shape === "cone") {
        const half = ((area.angle_deg ?? 90) * Math.PI) / 360;
        geo = new THREE.CircleGeometry(r + e.r, 32, -half, half * 2);
      } else if (area.shape === "line" || area.shape === "box") {
        const len = area.length_studs ?? atk.range_studs, w = area.width_studs ?? 4;
        geo = new THREE.PlaneGeometry(len, w);
        geo.translate(len / 2, 0, 0);
      } else if (area.shape === "ring") {
        const w = area.width_studs ?? 4;
        geo = new THREE.RingGeometry(Math.max(0.1, r - w / 2), r + w / 2, 64);
      } else geo = new THREE.CircleGeometry(r, 40);
      geo.rotateX(-Math.PI / 2);
      return geo;
    };
    const group = new THREE.Group();
    const base = new THREE.Mesh(make(), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.22, depthWrite: false, side: THREE.DoubleSide }));
    const fill = new THREE.Mesh(make(), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.4, depthWrite: false, side: THREE.DoubleSide }));
    fill.position.y = 0.02;
    group.add(base, fill);
    group.position.set(tell.cx, this.game.groundHeight(tell.cx, tell.cz) + 0.08, tell.cz);
    group.rotation.y = Math.atan2(-tell.fz, tell.fx);
    group.userData = { tell, fill, base, shape: area.shape };
    this.scene.add(group);
    return group;
  }

  disposeObject(obj) {
    this.scene.remove(obj);
    obj.traverse((o) => {
      if (o.geometry) o.geometry.dispose();
      if (o.material && !Array.isArray(o.material) && !this.shared.has(o.material)) {
        if (o.material.map && o.material.map !== this.glowTex) o.material.map.dispose();
        o.material.dispose?.();
      }
    });
  }

  // ---------------------------------------------------------------- quality
  setQuality(setting) {
    let level = setting;
    if (setting === "auto" || !QUALITY[setting]) level = this.autoLevel || (matchMedia("(pointer: coarse)").matches ? "low" : "high");
    this.qualityLevel = level;
    this.qualitySetting = setting;
    const q = QUALITY[level];
    this.renderer.setPixelRatio(Math.min(devicePixelRatio || 1, q.ratio));
    this.renderer.shadowMap.enabled = q.shadows;
    this.moon.castShadow = q.shadows;
    if (q.shadows && this.moon.shadow.mapSize.x !== q.shadowSize) {
      this.moon.shadow.mapSize.set(q.shadowSize, q.shadowSize);
      this.moon.shadow.map?.dispose();
      this.moon.shadow.map = null;
    }
    for (const l of this.lights) l.visible = q.lights;
    for (const e of this.edges) e.visible = q.edges;
    this.scene.traverse((o) => { if (o.material) for (const m of [].concat(o.material)) m.needsUpdate = true; });
    this.resize();
  }

  // On "auto", step quality down if the frame rate stays low.
  watchFps(dt) {
    if (this.qualitySetting !== "auto") return;
    const f = this.fps;
    f.frames++; f.time += dt;
    if (f.time < 3) return;
    const fps = f.frames / f.time;
    f.frames = 0; f.time = 0;
    const order = ["low", "medium", "high", "ultra"];
    const i = order.indexOf(this.qualityLevel);
    if (fps < 40 && i > 0) { this.autoLevel = order[i - 1]; this.setQuality("auto"); }
  }

  resize() {
    const w = innerWidth, h = innerHeight;
    this.w = w; this.h = h;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.fov = w < h ? 72 : 58; // wider view on portrait phones
    this.camera.updateProjectionMatrix();
  }

  // ---------------------------------------------------------------- camera
  rotateCamera(dx, dy) {
    this.yaw -= dx;
    this.pitch = Math.min(MAX_PITCH, Math.max(MIN_PITCH, this.pitch + dy));
    this.lastCameraInput = performance.now();
  }

  zoomBy(d) { this.zoom = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, this.zoom + d)); }

  updateCamera(dt) {
    const g = this.game, p = g.player;
    if (!p) return;
    const lock = g.lockTarget;
    if (lock?.alive) {
      const desired = Math.atan2(-(lock.x - p.x), -(lock.z - p.z));
      let diff = desired - this.yaw;
      diff = Math.atan2(Math.sin(diff), Math.cos(diff));
      this.yaw += diff * Math.min(1, dt * 6);
    } else if (this.autoFollow && g.moveDir && performance.now() - this.lastCameraInput > 1500) {
      // touch: drift behind the direction of travel when the player is not steering the camera
      const m = g.moveDir;
      if (Math.hypot(m.x, m.z) > 0.3) {
        const desired = Math.atan2(-m.x, -m.z);
        let diff = desired - this.yaw;
        diff = Math.atan2(Math.sin(diff), Math.cos(diff));
        if (Math.abs(diff) < 2.6) this.yaw += diff * Math.min(1, dt * 0.9);
      }
    }
    g.viewYaw = this.yaw;
    const ground = g.groundHeight(p.x, p.z);
    const target = new THREE.Vector3(p.x, ground + 3.2, p.z);
    const back = new THREE.Vector3(Math.sin(this.yaw) * Math.cos(this.pitch), Math.sin(this.pitch), Math.cos(this.yaw) * Math.cos(this.pitch));
    let distance = this.zoom;
    this.raycaster.set(target, back);
    this.raycaster.far = this.zoom;
    const hit = this.raycaster.intersectObjects(this.occluders, false)[0];
    if (hit) distance = Math.max(3, hit.distance - 0.6);
    const pos = target.clone().addScaledVector(back, distance);
    const shake = g.camera.shake * (g.setting("motion_intensity") ?? 1);
    if (shake > 0.01) pos.add(new THREE.Vector3(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).multiplyScalar(shake * 0.8));
    this.camera.position.copy(pos);
    this.camera.lookAt(target);
    // keep the shadow camera and sky around the player
    this.moon.position.set(p.x - 60, 140, p.z + 50);
    this.moon.target.position.set(p.x, 0, p.z);
    this.stars.position.set(p.x, 0, p.z);
    this.eclipse.position.set(p.x - 420, 260, p.z - 820);
    this.sky.position.set(p.x, 0, p.z);
  }

  // ---------------------------------------------------------------- per frame
  draw(dt) {
    const g = this.game, t = g.t;
    this.watchFps(dt);
    this.updateCamera(dt);
    this.updatePlayer(dt);
    this.updateEnemies(t);
    this.updateTells(t);
    this.updateFx(t);
    this.hubLantern.position.y = 7 + Math.sin(t * 1.5) * 0.4;
    for (const c of this.crystals) { c.rotation.y = t; c.position.y = 3 + Math.sin(t * 2) * 0.3; }
    for (const s of this.secrets) {
      s.mesh.visible = !g.save.secrets.includes(s.id);
      s.mesh.rotation.y = t * 2;
    }
    if (this.water) this.water.material.opacity = 0.8 + Math.sin(t * 0.8) * 0.05;
    this.renderer.render(this.scene, this.camera);
    this.updateOverlay(t);
  }

  updatePlayer(dt) {
    const g = this.game, p = g.player, m = this.player, t = g.t;
    if (!p) return;
    m.group.visible = !p.dead;
    const ground = g.groundHeight(p.x, p.z);
    const moving = g.moveDir && Math.hypot(g.moveDir.x, g.moveDir.z) > 0.1;
    const bob = moving ? Math.abs(Math.sin(t * 10)) * 0.15 * (g.setting("motion_intensity") ?? 1) : 0;
    m.group.position.set(p.x, ground + bob, p.z);
    m.group.rotation.y = Math.atan2(p.face.x, p.face.z);
    m.group.rotation.x = p.dash && t < p.dash.until ? 0.35 : 0;
    m.group.rotation.z = t < p.stunnedUntil ? Math.sin(t * 30) * 0.12 : 0;
    m.body.material = t < p.iframesUntil ? this.ghostMat : m.bodyMat;
    // sword: rest, guard or swing
    const s = p.swing;
    if (p.guarding) {
      m.pivot.rotation.set(-0.5, Math.PI / 2.2, 0);
    } else if (s) {
      const half = (s.arc * Math.PI) / 360;
      const u = (t - s.start - s.windup) / Math.max(s.active, 0.06);
      const from = s.flip ? -half : half, to = s.flip ? half : -half;
      const yaw = u < 0 ? from * 1.15 : from + (to - from) * Math.min(1, u);
      m.pivot.rotation.set(s.heavy ? -0.25 : 0, yaw, 0);
      this.updateTrail(s, p, ground);
    } else {
      m.pivot.rotation.set(2.3, 0.35, 0);
    }
    this.aura.intensity = 2.2 + (p.effects["abl_kindled_edge"] ? 1.5 : 0);
  }

  updateTrail(s, p, ground) {
    if (this.trail?.userData.start === s.start) {
      const u = (this.game.t - s.start - s.windup) / Math.max(s.active + 0.15, 0.1);
      this.trail.visible = u >= 0;
      this.trail.material.opacity = Math.max(0, 0.6 * (1 - u));
      return;
    }
    if (this.trail) this.disposeObject(this.trail);
    const half = (s.arc * Math.PI) / 360;
    const geo = new THREE.RingGeometry(1.2, s.range * 0.95, 32, 1, -half, half * 2);
    geo.rotateX(-Math.PI / 2);
    this.trail = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: s.heavy ? 0xffb347 : 0xffe0a0, transparent: true, opacity: 0.6, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending }));
    this.trail.position.set(p.x, ground + 1.6, p.z);
    this.trail.rotation.y = Math.atan2(-p.face.z, p.face.x);
    this.trail.visible = false;
    this.trail.userData.start = s.start;
    this.scene.add(this.trail);
  }

  updateEnemies(t) {
    const g = this.game;
    const seen = new Set();
    const flashLevel = g.setting("flash_intensity") ?? 1;
    this.flashMat.color.setScalar(0.45 + 0.55 * flashLevel);
    let boss = null;
    for (const e of g.enemies) {
      seen.add(e);
      const m = this.modelFor(e);
      const ground = g.groundHeight(e.x, e.z);
      m.group.position.set(e.x, ground, e.z);
      m.group.rotation.y = Math.atan2(e.face.x, e.face.z);
      const tell = e.tell;
      const progress = tell && !tell.active ? Math.min(1, (t - tell.t0) / tell.dur) : 0;
      if (m.arms) {
        const raise = tell ? (tell.active ? -0.3 : -2.3 * progress) : Math.sin(t * 1.5) * 0.1;
        for (const arm of m.arms) arm.rotation.x += (raise - arm.rotation.x) * 0.25;
        m.torso.position.y = 9.5 + (tell?.atk.area.shape === "ring" && !tell.active ? -progress * 1.5 : 0);
      } else {
        const lean = tell ? (tell.active ? 0.35 : -0.4 * progress) : 0;
        m.torso.rotation.x += (lean - m.torso.rotation.x) * 0.3;
        m.torso.position.y = Math.sin(t * 4 + e.x) * 0.08;
      }
      m.group.rotation.z = t < e.stunnedUntil ? Math.sin(t * 28) * 0.15 : 0;
      const flash = t < e.flashUntil && flashLevel > 0.05;
      for (const part of m.flashParts) part.material = flash ? this.flashMat : m.baseMat;
      m.burn.visible = !!e.burning && e.alive;
      if (m.burn.visible) m.burn.material.opacity = 0.45 + Math.sin(t * 12) * 0.2;
      if (e.isBoss) { this.bossLight.position.set(e.x, ground + 10, e.z); boss = e.alive ? e : boss; }
      if (!e.alive) {
        const u = Math.min(1, (t - e.deadAt) / 0.6);
        m.group.scale.setScalar(Math.max(0.05, 1 - u));
        m.group.position.y = ground - u;
      }
    }
    for (const [e, m] of this.models) {
      if (!seen.has(e)) { this.disposeObject(m.group); this.models.delete(e); }
    }
    this.bossLight.intensity = boss && this.qualityLevel !== "low" ? 3 : 0;
  }

  updateTells(t) {
    const g = this.game;
    for (const e of g.enemies) {
      const tell = e.tell;
      let mesh = this.tells.get(e);
      const was = mesh?.userData.tell; // the active phase copies atk and position from the warning
      if (mesh && (!tell || tell.atk !== was.atk || tell.cx !== was.cx || tell.cz !== was.cz || (!tell.active && tell.t0 !== was.t0))) {
        this.disposeObject(mesh); this.tells.delete(e); mesh = null;
      }
      if (!tell) continue;
      if (!mesh) { mesh = this.tellMesh(e); this.tells.set(e, mesh); }
      const { fill, base, shape } = mesh.userData;
      if (tell.active) {
        base.material.opacity = 0.55;
        fill.visible = false;
      } else {
        const u = Math.min(1, (t - tell.t0) / tell.dur);
        if (shape === "line" || shape === "box") fill.scale.set(Math.max(0.01, u), 1, 1);
        else if (shape !== "ring") fill.scale.set(Math.max(0.01, u), 1, Math.max(0.01, u));
        else fill.material.opacity = 0.15 + 0.4 * u;
      }
    }
    for (const [e, mesh] of this.tells) {
      if (!g.enemies.includes(e) || !e.tell) { this.disposeObject(mesh); this.tells.delete(e); }
    }
  }

  updateFx(t) {
    const g = this.game;
    const live = new Set(g.fx);
    for (const f of g.fx) {
      if (f.type === "number") continue; // drawn in the overlay
      let obj = this.fxObjects.get(f);
      const u = (t - f.t0) / f.dur;
      if (!obj) {
        obj = this.makeFx(f);
        if (!obj) continue;
        this.fxObjects.set(f, obj);
        this.scene.add(obj);
      }
      if (f.type === "wave") {
        const along = (f.len ?? 40) * Math.min(1, u * 1.1);
        obj.position.set(f.x + f.fx * along, g.groundHeight(f.x, f.z) + 1.4, f.z + f.fz * along);
        obj.traverse((o) => { if (o.material) o.material.opacity = 0.9 * (1 - u * 0.6); });
      } else if (f.type === "burst" || f.type === "levelup") {
        obj.scale.setScalar(1 + u * (f.type === "levelup" ? 5 : 2));
        obj.material.opacity = 0.8 * (1 - u);
        if (f.type === "levelup" && g.player) obj.position.set(g.player.x, g.groundHeight(g.player.x, g.player.z) + 0.2 + u * 3, g.player.z);
      } else if (f.type === "dash") {
        obj.material.opacity = 0.45 * (1 - u);
      } else if (f.type === "cast" && g.player) {
        obj.position.set(g.player.x, g.groundHeight(g.player.x, g.player.z) + 1.6, g.player.z);
        obj.scale.setScalar(2 + u * 6);
      }
    }
    for (const [f, obj] of this.fxObjects) {
      if (!live.has(f)) { this.disposeObject(obj); this.fxObjects.delete(f); }
    }
  }

  makeFx(f) {
    const g = this.game;
    if (f.type === "wave") {
      const geo = new THREE.TorusGeometry((f.w ?? 6) / 2, 0.45, 8, 24, Math.PI);
      geo.rotateX(-Math.PI / 2); // flat, bulging toward -z
      geo.scale(1, 2.2, 1);
      const mesh = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0xffa646, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false }));
      mesh.rotation.y = Math.atan2(-f.fx, -f.fz);
      const group = new THREE.Group();
      group.add(mesh, this.glow(0xff8a30, 9, 0.9));
      return group;
    }
    if (f.type === "burst" || f.type === "levelup") {
      const geo = new THREE.RingGeometry(0.8, 1.1, 40);
      geo.rotateX(-Math.PI / 2);
      const mesh = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: f.type === "levelup" ? 0xf2c14e : f.boss ? 0xffd682 : 0x9a9aae, transparent: true, opacity: 0.8, depthWrite: false, side: THREE.DoubleSide }));
      mesh.position.set(f.x ?? 0, g.groundHeight(f.x ?? 0, f.z ?? 0) + 0.3, f.z ?? 0);
      if (f.r) mesh.scale.setScalar(f.r);
      return mesh;
    }
    if (f.type === "dash") {
      const mesh = new THREE.Mesh(new THREE.CapsuleGeometry(0.75, 1.2, 4, 10), new THREE.MeshBasicMaterial({ color: 0x9fc4ff, transparent: true, opacity: 0.45, depthWrite: false }));
      mesh.position.set(f.x, g.groundHeight(f.x, f.z) + 1.35, f.z);
      return mesh;
    }
    if (f.type === "cast") return this.glow(0xffaa46, 2, 0.9);
    return null;
  }

  // ---------------------------------------------------------------- DOM overlay (names, bars, numbers)
  project(x, y, z) {
    this.tmp.set(x, y, z).project(this.camera);
    if (this.tmp.z > 1) return null;
    return [((this.tmp.x + 1) / 2) * this.w, ((1 - this.tmp.y) / 2) * this.h];
  }

  label(key, cls, html) {
    let el = this.labels.get(key);
    if (!el) {
      el = document.createElement("div");
      el.className = `wl ${cls}`;
      this.overlay.append(el);
      this.labels.set(key, el);
    }
    if (el._html !== html) { el.innerHTML = html; el._html = html; }
    el._seen = true;
    return el;
  }

  place(el, pos) {
    if (!pos || pos[0] < -60 || pos[0] > this.w + 60 || pos[1] < -60 || pos[1] > this.h + 60) { el.style.display = "none"; return; }
    el.style.display = "";
    el.style.transform = `translate(${pos[0]}px, ${pos[1]}px) translate(-50%, -100%)`;
  }

  updateOverlay(t) {
    const g = this.game, p = g.player;
    for (const el of this.labels.values()) el._seen = false;
    const near = (x, z, d) => p && Math.hypot(x - p.x, z - p.z) <= d;
    for (const l of g.map.landmarks) {
      if (!near(l.position[0], l.position[2], 260)) continue;
      const el = this.label(`lm-${l.id}`, "landmark", l.name);
      this.place(el, this.project(l.position[0], Math.min(l.position[1] + l.size[1] + 4, 130), l.position[2]));
    }
    if (near(g.hub.position[0], g.hub.position[2], 200)) this.place(this.label("hub", "hub", g.hub.name), this.project(g.hub.position[0], 10, g.hub.position[2]));
    for (const f of g.map.fast_travel) if (near(f.position[0], f.position[2], 150)) this.place(this.label(`ft-${f.id}`, "ft", f.name), this.project(f.position[0], 6, f.position[2]));
    const palette = TELL[g.setting("colorblind")] || TELL.none;
    for (const e of g.enemies) {
      if (!e.alive || !near(e.x, e.z, 55)) continue;
      const height = e.isBoss ? 17 : 3.6;
      const top = this.project(e.x, g.groundHeight(e.x, e.z) + height, e.z);
      if (!e.isBoss) {
        const pct = Math.round((e.hp / e.maxHp) * 100);
        const el = this.label(e, "enemy", `<div class="n">${e.def.name} <span>Lv ${e.level}</span></div><div class="b"><i style="width:${pct}%"></i></div>`);
        this.place(el, top);
      }
      if (e.tell?.unblockable && !e.tell.active) {
        const el = this.label(`ub-${g.enemies.indexOf(e)}-${e.tell.t0}`, "unblockable", "!");
        el.style.color = `#${palette.unblockable.toString(16).padStart(6, "0")}`;
        this.place(el, top && [top[0], top[1] - 26]);
      }
      if (g.lockTarget === e) this.place(this.label("lock", "lock", "◇"), this.project(e.x, g.groundHeight(e.x, e.z) + height * 0.55, e.z));
      if (t < e.stunnedUntil) this.place(this.label(`st-${g.enemies.indexOf(e)}`, "stars", "✦ ✦"), top && [top[0], top[1] - 22]);
    }
    for (const f of g.fx) {
      if (f.type !== "number") continue;
      const u = (t - f.t0) / f.dur;
      const el = this.label(f, f.big ? "num big" : "num", f.text);
      el.style.color = f.color;
      el.style.opacity = String(1 - Math.max(0, u - 0.5) * 2);
      this.place(el, this.project(f.x, g.groundHeight(f.x, f.z) + 3 + u * 2.5, f.z));
    }
    for (const [key, el] of this.labels) if (!el._seen) { el.remove(); this.labels.delete(key); }
    if (!this.vignette) { this.vignette = document.createElement("div"); this.vignette.id = "vignette"; this.overlay.prepend(this.vignette); }
    const low = p && !p.dead && p.hp / p.maxHp < 0.35;
    this.vignette.style.opacity = low ? String(0.5 + 0.5 * (g.setting("flash_intensity") ?? 1)) : "0";
  }
}
