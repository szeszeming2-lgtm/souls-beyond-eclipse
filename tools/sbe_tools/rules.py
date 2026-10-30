"""Cross-file design rules.

The schemas check each file on its own. These rules check things that need
several files at once, and they turn design promises from the project brief
into automatic checks (every enemy attack can be avoided, no stun-locks, no
level-band gaps, cosmetics never give power, and so on).

Each rule is a function that receives a Ctx and reports problems through it.
Rules only run after every file has passed its schema, so they can assume the
basic shape of the data is right.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any, Callable, Iterator

from . import xp_curve
from .catalog import DataFile, Entity
from .schema import SchemaStore

LEVEL_CAP = 3000
REQUIRED_MAJOR_MILESTONES = (100, 500, 1000, 1500, 2000, 2500, 3000)
REQUIRED_INPUT_ACTIONS = (
    "move", "camera", "light_attack", "heavy_attack", "guard", "jump", "dodge_sprint",
    "ability_1", "ability_2", "ability_3", "ultimate", "lock_on", "interact", "pause",
    "menu_navigate", "menu_confirm", "menu_back",
)
SINGLETON_SCHEMAS = (
    "combat.schema.json", "progression.schema.json", "xp_table.schema.json",
    "difficulty.schema.json", "input_actions.schema.json", "customization.schema.json",
)
COLLECTION_SCHEMAS = (
    "factions.schema.json", "archetypes.schema.json", "skill_trees.schema.json",
    "movesets.schema.json", "abilities.schema.json", "status_effects.schema.json",
    "weapons.schema.json", "materials.schema.json", "enemies.schema.json",
    "characters.schema.json", "quests.schema.json", "regions.schema.json", "assets.schema.json",
)
# Inputs that act like a pointer: their meaning depends on what is under them, so they never conflict.
POINTER_INPUTS = frozenset({"TouchTap"})
COMPOSITES = {
    "Composite:WASD": ("W", "A", "S", "D"),
    "Composite:Arrows": ("Up", "Down", "Left", "Right"),
    "Composite:DPad": ("DPadUp", "DPadDown", "DPadLeft", "DPadRight"),
}
# Asset kinds used globally by UI code rather than referenced from data.
GLOBAL_ASSET_KINDS = frozenset({"font", "ui"})


@dataclass
class Ctx:
    files: list[DataFile]
    registry: dict[str, Entity]
    store: SchemaStore
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def error(self, where: str, message: str) -> None:
        self.errors.append(f"{where}: {message}")

    def warn(self, where: str, message: str) -> None:
        self.warnings.append(f"{where}: {message}")

    def files_for(self, schema_name: str) -> list[DataFile]:
        return [f for f in self.files if f.schema_name == schema_name]

    def single(self, schema_name: str) -> DataFile | None:
        found = self.files_for(schema_name)
        return found[0] if len(found) == 1 else None

    def entries(self, schema_name: str) -> Iterator[tuple[str, dict]]:
        """(where, entry) for every entry of a collection, across all its files."""
        for data_file in self.files_for(schema_name):
            for index, entry in enumerate(data_file.data["entries"]):
                yield f"{data_file.rel}: entries[{index}] ({entry['id']})", entry

    def get(self, ident: str | None) -> dict | None:
        if ident is None or ident not in self.registry:
            return None
        return self.registry[ident].obj

    def where(self, ident: str) -> str:
        entity = self.registry.get(ident)
        return f"{entity.file}: {entity.path} ({ident})" if entity else ident


RULES: list[Callable[[Ctx], None]] = []


def rule(fn: Callable[[Ctx], None]) -> Callable[[Ctx], None]:
    RULES.append(fn)
    return fn


def _find_cycle(graph: dict[str, list[str]]) -> list[str] | None:
    """Return one cycle in a directed graph as a list of nodes, or None."""
    WHITE, GREY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}
    stack: list[str] = []

    def visit(node: str) -> list[str] | None:
        color[node] = GREY
        stack.append(node)
        for nxt in graph.get(node, ()):
            if color.get(nxt, BLACK) == GREY:
                return stack[stack.index(nxt):] + [nxt]
            if color.get(nxt) == WHITE:
                found = visit(nxt)
                if found:
                    return found
        stack.pop()
        color[node] = BLACK
        return None

    for node in graph:
        if color[node] == WHITE:
            found = visit(node)
            if found:
                return found
    return None


# --------------------------------------------------------------------------- files
@rule
def required_files(ctx: Ctx) -> None:
    for name in SINGLETON_SCHEMAS:
        count = len(ctx.files_for(name))
        if count != 1:
            ctx.error("shared-data", f"expected exactly one file using {name}, found {count}")
    for name in COLLECTION_SCHEMAS:
        if not ctx.files_for(name):
            ctx.error("shared-data", f"no data file uses {name}")


# --------------------------------------------------------------------------- weapons
@rule
def weapon_rules(ctx: Ctx) -> None:
    archetype_classes = {c for _, a in ctx.entries("archetypes.schema.json") for c in a["weapon_classes"]}
    slot_kinds = (("special_ability_id", "special"), ("passive_ability_id", "passive"), ("ultimate_ability_id", "ultimate"))
    for where, weapon in ctx.entries("weapons.schema.json"):
        tiers = weapon["upgrade_tiers"]
        numbers = [t["tier"] for t in tiers]
        if numbers != [1, 2, 3, 4, 5]:
            ctx.error(where, f"upgrade tiers must be numbered 1, 2, 3, 4, 5 in order, got {numbers}")
        bonuses = [t["damage_bonus_pct"] for t in tiers]
        if any(b <= a for a, b in zip(bonuses, bonuses[1:])):
            ctx.error(where, f"damage_bonus_pct must increase every tier, got {bonuses}")
        last_level = weapon["level_req"]
        for tier in tiers:
            min_level = tier.get("min_level", last_level)
            if min_level < last_level:
                ctx.error(where, f"tier {tier['tier']} min_level {min_level} is below an earlier requirement ({last_level})")
            last_level = max(last_level, min_level)
        for field_name, kind in slot_kinds:
            ability = ctx.get(weapon.get(field_name))
            if ability is not None and ability["kind"] != kind:
                ctx.error(where, f"{field_name} {weapon[field_name]!r} must be an ability of kind {kind!r}, not {ability['kind']!r}")
        moveset = ctx.get(weapon["moveset_id"])
        if moveset is not None and moveset["weapon_class"] != weapon["weapon_class"]:
            ctx.error(where, f"moveset {weapon['moveset_id']!r} is for {moveset['weapon_class']!r}, but this weapon is a {weapon['weapon_class']!r}")
        if weapon["weapon_class"] not in archetype_classes:
            ctx.warn(where, f"no archetype can use weapon class {weapon['weapon_class']!r}")


# --------------------------------------------------------------------------- archetypes & factions
@rule
def archetype_rules(ctx: Ctx) -> None:
    slots = (
        ("defensive_ability_id", "defensive"),
        ("mobility_ability_id", "mobility"),
        ("starting_ability_id", "active"),
        ("ultimate_ability_id", "ultimate"),
    )
    for where, arc in ctx.entries("archetypes.schema.json"):
        for field_name, kind in slots:
            ability = ctx.get(arc.get(field_name))
            if ability is not None and ability["kind"] != kind:
                ctx.error(where, f"{field_name} {arc[field_name]!r} must be an ability of kind {kind!r}, not {ability['kind']!r}")
        for ability_id in arc.get("unlockable_ability_ids", []):
            ability = ctx.get(ability_id)
            if ability is not None and ability["kind"] != "active":
                ctx.error(where, f"unlockable ability {ability_id!r} must be of kind 'active', not {ability['kind']!r}")
        if arc.get("starting_ability_id") in arc.get("unlockable_ability_ids", []):
            ctx.error(where, "the starting ability must not also be listed as unlockable")
        ultimate = ctx.get(arc.get("ultimate_ability_id"))
        if ultimate is not None and "transformation" not in ultimate:
            ctx.error(where, f"archetype ultimate {arc['ultimate_ability_id']!r} must be a transformation (needs a 'transformation' block)")
        moveset = ctx.get(arc.get("default_moveset_id"))
        if moveset is not None and moveset["weapon_class"] not in arc["weapon_classes"]:
            ctx.error(where, f"default moveset is for {moveset['weapon_class']!r}, which is not in weapon_classes")
        tree = ctx.get(arc.get("skill_tree_id"))
        if tree is not None and tree["archetype_id"] != arc["id"]:
            ctx.error(where, f"skill tree {arc['skill_tree_id']!r} belongs to {tree['archetype_id']!r}")
        faction = ctx.get(arc["faction_id"])
        if faction is not None and arc["id"] not in faction["archetype_ids"]:
            ctx.error(where, f"faction {arc['faction_id']!r} does not list this archetype in archetype_ids")
    for where, faction in ctx.entries("factions.schema.json"):
        for arc_id in faction["archetype_ids"]:
            arc = ctx.get(arc_id)
            if arc is not None and arc["faction_id"] != faction["id"]:
                ctx.error(where, f"archetype {arc_id!r} says it belongs to {arc['faction_id']!r}")
    playable = [f for _, f in ctx.entries("factions.schema.json") if f["playable"]]
    if not 4 <= len(playable) <= 6:
        ctx.error("factions", f"the brief asks for 4-6 playable factions, found {len(playable)}")


@rule
def skill_tree_rules(ctx: Ctx) -> None:
    for where, tree in ctx.entries("skill_trees.schema.json"):
        node_ids = [n["id"] for n in tree["nodes"]]
        seen: set[str] = set()
        for node_id in node_ids:
            if node_id in seen:
                ctx.error(where, f"node id {node_id!r} is used twice in this tree")
            seen.add(node_id)
        graph = {n["id"]: list(n["requires"]) for n in tree["nodes"]}
        for node in tree["nodes"]:
            for req in node["requires"]:
                if req == node["id"]:
                    ctx.error(where, f"node {node['id']!r} requires itself")
                elif req not in seen:
                    ctx.error(where, f"node {node['id']!r} requires {req!r}, which is not a node in this tree")
        if not any(not n["requires"] for n in tree["nodes"]):
            ctx.error(where, "the tree needs at least one starting node (a node with no requirements)")
        cycle = _find_cycle(graph)
        if cycle:
            ctx.error(where, f"requirement loop: {' -> '.join(cycle)}")
        arc = ctx.get(tree["archetype_id"])
        if arc is not None and arc.get("skill_tree_id") != tree["id"]:
            ctx.error(where, f"archetype {tree['archetype_id']!r} does not point back to this tree")
        if arc is not None:
            for node in tree["nodes"]:
                effect = node["effect"]
                if effect["type"] == "unlock_ability" and effect["ability_id"] not in arc.get("unlockable_ability_ids", []):
                    ctx.warn(where, f"node {node['id']!r} unlocks {effect['ability_id']!r}, which the archetype does not list as unlockable")


# --------------------------------------------------------------------------- abilities & status effects
@rule
def ability_rules(ctx: Ctx) -> None:
    progression = ctx.single("progression.schema.json")
    spirit_max = progression.data["stat_scaling"]["spirit_max"] if progression else 100
    for where, ability in ctx.entries("abilities.schema.json"):
        levels = [u["level"] for u in ability["upgrade_levels"]]
        expected = list(range(2, 2 + len(levels)))
        if levels != expected:
            ctx.error(where, f"upgrade levels must be {expected} in order, got {levels}")
        cost = ability["cost"]
        if cost["resource"] == "none" and cost["amount"] != 0:
            ctx.error(where, "cost.amount must be 0 when cost.resource is 'none'")
        if cost["resource"] == "spirit" and cost["amount"] > spirit_max:
            ctx.error(where, f"costs {cost['amount']} spirit but the meter only holds {spirit_max}")
        if ability["kind"] == "passive" and (ability["cooldown_s"] != 0 or cost["amount"] != 0):
            ctx.error(where, "passive abilities have no cooldown and no cost")


@rule
def crowd_control_rules(ctx: Ctx) -> None:
    combat = ctx.single("combat.schema.json")
    if combat is None:
        return
    max_cc = combat.data["crowd_control"]["max_hard_cc_s"]
    for where, effect in ctx.entries("status_effects.schema.json"):
        if effect["category"] == "hard_cc" and effect["duration_s"] > max_cc:
            ctx.error(where, f"hard crowd control lasts {effect['duration_s']} s; the limit is {max_cc} s (no stun-locks)")
    # Overrides of a hard-cc duration in abilities or enemy attacks must respect the same limit.
    sources = [(w, a.get("status_effects", [])) for w, a in ctx.entries("abilities.schema.json")]
    for where, enemy in ctx.entries("enemies.schema.json"):
        for attack in enemy["attacks"]:
            sources.append((f"{where} attack {attack['id']!r}", attack.get("status_effects", [])))
    for where, applications in sources:
        for app in applications:
            effect = ctx.get(app["status_id"])
            if effect and effect["category"] == "hard_cc" and app.get("duration_s", 0) > max_cc:
                ctx.error(where, f"applies {app['status_id']!r} for {app['duration_s']} s; the hard-cc limit is {max_cc} s")


# --------------------------------------------------------------------------- enemies & bosses
@rule
def enemy_rules(ctx: Ctx) -> None:
    combat = ctx.single("combat.schema.json")
    difficulty = ctx.single("difficulty.schema.json")
    if combat is None or difficulty is None:
        return
    readability = combat.data["readability"]
    modes = difficulty.data["modes"]
    for where, enemy in ctx.entries("enemies.schema.json"):
        attack_ids = [a["id"] for a in enemy["attacks"]]
        if len(set(attack_ids)) != len(attack_ids):
            ctx.error(where, f"attack ids must be unique within an enemy: {attack_ids}")
        for attack in enemy["attacks"]:
            label = f"{where} attack {attack['id']!r}"
            windup = attack["timing"]["windup_s"]
            unblockable = "guard" not in attack["avoidable_by"]
            for mode in modes:
                effective = windup * mode["telegraph_time_mult"]
                if effective + 1e-9 < readability["min_telegraph_s"]:
                    ctx.error(label, f"wind-up is {effective:.3f} s on {mode['id']}; the minimum readable tell is {readability['min_telegraph_s']} s")
                if unblockable and effective + 1e-9 < readability["min_unblockable_telegraph_s"]:
                    ctx.error(label, f"unblockable wind-up is {effective:.3f} s on {mode['id']}; unblockable attacks need at least {readability['min_unblockable_telegraph_s']} s")
            if unblockable:
                if "dodge" not in attack["avoidable_by"]:
                    ctx.error(label, "an unblockable attack must be dodgeable")
                if not attack["tell"].get("unblockable_marker"):
                    ctx.error(label, "an unblockable attack must show the unblockable marker (tell.unblockable_marker = true)")
            if attack["knockback_studs"] > readability["max_knockback_studs"]:
                ctx.error(label, f"knockback {attack['knockback_studs']} is above the limit {readability['max_knockback_studs']}")
        for drop in enemy["rewards"]["drops"]:
            if drop["qty_min"] > drop["qty_max"]:
                ctx.error(where, f"drop {drop['item_id']!r} has qty_min above qty_max")
        boss = enemy.get("boss")
        if boss is None:
            continue
        phases = boss["phases"]
        starts = [p["starts_at_hp"] for p in phases]
        if starts[0] != 1:
            ctx.error(where, f"the first boss phase must start at 1 (full HP), got {starts[0]}")
        if any(b >= a for a, b in zip(starts, starts[1:])):
            ctx.error(where, f"boss phases must start at decreasing HP fractions, got {starts}")
        phase_ids = [p["id"] for p in phases]
        if len(set(phase_ids)) != len(phase_ids):
            ctx.error(where, f"phase ids must be unique: {phase_ids}")
        used: set[str] = set()
        for phase in phases:
            for attack_id in phase["attack_ids"]:
                used.add(attack_id)
                if attack_id not in attack_ids:
                    ctx.error(where, f"phase {phase['id']!r} uses unknown attack {attack_id!r}")
        for attack_id in attack_ids:
            if attack_id not in used:
                ctx.warn(where, f"attack {attack_id!r} is not used in any boss phase")
        arena = ctx.get(boss["arena_id"])
        if arena is not None and arena["boss_id"] != enemy["id"]:
            ctx.error(where, f"arena {boss['arena_id']!r} is set up for {arena['boss_id']!r}")


# --------------------------------------------------------------------------- progression
@rule
def progression_rules(ctx: Ctx) -> None:
    progression = ctx.single("progression.schema.json")
    if progression is None:
        return
    data = progression.data
    where = progression.rel
    cap = data["level_cap"]

    bands = sorted(data["level_bands"], key=lambda b: b["min"])
    if bands[0]["min"] != 1:
        ctx.error(where, f"level bands must start at level 1, first starts at {bands[0]['min']}")
    if bands[-1]["max"] != cap:
        ctx.error(where, f"level bands must end at the cap ({cap}), last ends at {bands[-1]['max']}")
    for band in bands:
        if band["min"] > band["max"]:
            ctx.error(where, f"band {band['id']!r} has min above max")
    for a, b in zip(bands, bands[1:]):
        if b["min"] != a["max"] + 1:
            ctx.error(where, f"gap or overlap between bands {a['id']!r} (ends {a['max']}) and {b['id']!r} (starts {b['min']})")

    milestones = data["milestones"]
    major_levels = [m["level"] for m in milestones["major"]]
    if len(set(major_levels)) != len(major_levels):
        ctx.error(where, f"major milestone levels repeat: {major_levels}")
    for level in major_levels:
        if level % milestones["interval"] != 0:
            ctx.error(where, f"major milestone {level} is not a multiple of {milestones['interval']}")
    for level in REQUIRED_MAJOR_MILESTONES:
        if level not in major_levels:
            ctx.error(where, f"missing the major milestone at level {level}")

    schedule = sorted(data["skill_points"]["schedule"], key=lambda s: s["from"])
    if schedule[0]["from"] != 2 or schedule[-1]["to"] != cap:
        ctx.error(where, f"skill point schedule must cover levels 2 to {cap}")
    for item in schedule:
        if item["from"] > item["to"]:
            ctx.error(where, f"skill point range {item['from']}-{item['to']} is backwards")
    for a, b in zip(schedule, schedule[1:]):
        if b["from"] != a["to"] + 1:
            ctx.error(where, f"skill point ranges {a['from']}-{a['to']} and {b['from']}-{b['to']} have a gap or overlap")

    source_ids = [s["id"] for s in data["xp_sources"]]
    if len(set(source_ids)) != len(source_ids):
        ctx.error(where, f"xp_sources ids repeat: {source_ids}")

    curve = data["xp_curve"]
    for problem in xp_curve.check_pace_points(curve, cap):
        ctx.error(where, f"xp_curve: {problem}")

    table_file = ctx.single("xp_table.schema.json")
    if table_file is None or xp_curve.check_pace_points(curve, cap):
        return
    table = table_file.data["xp_to_next"]
    if table_file.data["level_cap"] != cap:
        ctx.error(table_file.rel, "level_cap does not match progression.json")
    expected = xp_curve.build_table(curve, cap)
    if table != expected:
        first = next((i for i, (a, b) in enumerate(zip(table, expected)) if a != b), min(len(table), len(expected)))
        ctx.error(
            table_file.rel,
            f"out of date with progression.json (first difference at level {first + 1}). "
            "Run: python3 tools/xp_sim/xp_sim.py --write-table",
        )
        return
    for level in range(2, len(table) + 1):
        if table[level - 1] < table[level - 2]:
            ctx.error(table_file.rel, f"XP needed goes down at level {level}; later levels must never get cheaper")
            break
    # "Never hit a wall": no level may cost much more XP than the one before it.
    # Early levels take a minute or two each, so they may ramp faster.
    # table[L - 1] is the cost of finishing level L.
    for level in range(2, len(table) + 1):
        ratio = table[level - 1] / table[level - 2]
        limit = 1.30 if level < 30 else 1.05
        if ratio > limit:
            ctx.error(table_file.rel, f"XP jumps {ratio:.2f}x at level {level}: that is a wall (limit {limit}x)")
            break


# --------------------------------------------------------------------------- world: regions, maps, quests
@rule
def region_rules(ctx: Ctx) -> None:
    progression = ctx.single("progression.schema.json")
    bands = {b["id"]: b for b in progression.data["level_bands"]} if progression else {}
    regions = dict((r["id"], (w, r)) for w, r in ctx.entries("regions.schema.json"))
    regions_per_band: dict[str, int] = defaultdict(int)
    maps_by_id = {f.data["id"]: f for f in ctx.files_for("map.schema.json")}
    for region_id, (where, region) in regions.items():
        lo, hi = region["level_range"]["min"], region["level_range"]["max"]
        if lo > hi:
            ctx.error(where, "level_range min is above max")
        band = bands.get(region["band_id"])
        if band is None:
            ctx.error(where, f"band {region['band_id']!r} is not defined in progression.json")
        else:
            regions_per_band[band["id"]] += 1
            if lo < band["min"] or hi > band["max"]:
                ctx.error(where, f"levels {lo}-{hi} fall outside its band {band['id']!r} ({band['min']}-{band['max']})")
        if region["dev_status"] != "concept" and not region["map_ids"]:
            ctx.error(where, "a region beyond the concept stage needs at least one map")
        for map_id in region["map_ids"]:
            map_file = maps_by_id.get(map_id)
            if map_file is not None and map_file.data["region_id"] != region_id:
                ctx.error(where, f"map {map_id!r} says it belongs to {map_file.data['region_id']!r}")
        for boss_id in region["boss_ids"]:
            boss = ctx.get(boss_id)
            if boss is not None and boss["rank"] not in ("boss", "secret_boss"):
                ctx.error(where, f"{boss_id!r} is listed as a boss but its rank is {boss['rank']!r}")
        for other in region["connects_to"]:
            if other == region_id:
                ctx.error(where, "a region cannot connect to itself")
            elif other in regions and region_id not in regions[other][1]["connects_to"]:
                ctx.error(where, f"connects to {other!r}, but {other!r} does not connect back")
    for band_id in bands:
        if regions_per_band[band_id] == 0:
            ctx.error(progression.rel if progression else "progression", f"band {band_id!r} has no region")
    # One connected world: every region must be reachable from the first.
    if regions:
        start = next(iter(regions))
        seen, todo = {start}, [start]
        while todo:
            for nxt in regions[todo.pop()][1]["connects_to"]:
                if nxt in regions and nxt not in seen:
                    seen.add(nxt)
                    todo.append(nxt)
        for region_id in regions:
            if region_id not in seen:
                ctx.error(regions[region_id][0], f"cannot be reached from {start!r}; the world must be connected")
    for map_file in maps_by_id.values():
        region = regions.get(map_file.data["region_id"])
        if region and map_file.data["id"] not in region[1]["map_ids"]:
            ctx.error(map_file.rel, f"region {map_file.data['region_id']!r} does not list this map in map_ids")


@rule
def map_rules(ctx: Ctx) -> None:
    for map_file in ctx.files_for("map.schema.json"):
        data = map_file.data
        where = map_file.rel
        lo, hi = data["bounds"]["min"], data["bounds"]["max"]
        if any(a >= b for a, b in zip(lo, hi)):
            ctx.error(where, f"bounds min {lo} must be below max {hi} on every axis")
            continue

        def inside(point: list[float], label: str) -> None:
            if not all(a <= p <= b for a, p, b in zip(lo, point, hi)):
                ctx.error(where, f"{label} at {point} is outside the map bounds")

        inside(data["player_spawn"]["position"], "player_spawn")
        local_places: set[str] = set()
        for key, pos_field in (("hubs", "position"), ("fast_travel", "position"), ("landmarks", "position"),
                               ("spawn_zones", "center"), ("boss_arenas", "center"), ("secrets", "position")):
            for item in data[key]:
                local_places.add(item["id"])
                inside(item[pos_field], f"{key} {item['id']!r}")
        for arena in data["boss_arenas"]:
            inside(arena["checkpoint_position"], f"checkpoint of {arena['id']!r}")
            boss = ctx.get(arena["boss_id"])
            if boss is not None:
                if boss["rank"] not in ("boss", "secret_boss"):
                    ctx.error(where, f"arena {arena['id']!r} holds {arena['boss_id']!r}, which is not a boss")
                elif boss["boss"]["arena_id"] != arena["id"]:
                    ctx.error(where, f"arena {arena['id']!r}: boss {arena['boss_id']!r} names a different arena")
        route_ids: set[str] = set()
        for route in data["routes"]:
            if route["id"] in route_ids:
                ctx.error(where, f"route id {route['id']!r} is used twice")
            route_ids.add(route["id"])
            for end in ("from", "to"):
                if route[end] not in local_places:
                    ctx.error(where, f"route {route['id']!r} {end} {route[end]!r} is not a place on this map")
            for point in route["waypoints"]:
                inside(point, f"route {route['id']!r} waypoint")
        region = ctx.get(data["region_id"])
        for zone in data["spawn_zones"]:
            z_lo, z_hi = zone["level_range"]["min"], zone["level_range"]["max"]
            if z_lo > z_hi:
                ctx.error(where, f"spawn zone {zone['id']!r} level_range min is above max")
            if region and not (region["level_range"]["min"] <= z_lo and z_hi <= region["level_range"]["max"]):
                ctx.error(where, f"spawn zone {zone['id']!r} levels {z_lo}-{z_hi} are outside the region's range")
        for quest_id in data["side_quest_ids"]:
            quest = ctx.get(quest_id)
            if quest is not None and quest["region_id"] != data["region_id"]:
                ctx.error(where, f"side quest {quest_id!r} is set in {quest['region_id']!r}, not this map's region")
        for index, piece in enumerate(data["blockout"]):
            inside(piece["position"], f"blockout[{index}]")
            if any(s <= 0 for s in piece["size"]):
                ctx.error(where, f"blockout[{index}] size {piece['size']} must be above 0 on every axis")


@rule
def quest_rules(ctx: Ctx) -> None:
    progression = ctx.single("progression.schema.json")
    bands = {b["id"]: b for b in progression.data["level_bands"]} if progression else {}
    quests = {q["id"]: (w, q) for w, q in ctx.entries("quests.schema.json")}
    graph = {qid: list(q["prerequisites"]) for qid, (_, q) in quests.items()}
    for quest_id, (where, quest) in quests.items():
        objective_ids = [o["id"] for o in quest["objectives"]]
        if len(set(objective_ids)) != len(objective_ids):
            ctx.error(where, f"objective ids must be unique: {objective_ids}")
        level = quest["recommended_level"]
        band = bands.get(quest["band_id"])
        if band and not band["min"] <= level <= band["max"]:
            ctx.error(where, f"recommended level {level} is outside its band {band['id']!r}")
        region = ctx.get(quest["region_id"])
        if region and not region["level_range"]["min"] <= level <= region["level_range"]["max"]:
            ctx.error(where, f"recommended level {level} is outside the region's levels")
        if quest["type"] == "main":
            for req in quest["prerequisites"]:
                if req in quests and quests[req][1]["type"] != "main":
                    ctx.error(where, f"main quest requires side content {req!r}; the story must not depend on side activities")
        if quest_id in quest["prerequisites"]:
            ctx.error(where, "a quest cannot require itself")
    cycle = _find_cycle(graph)
    if cycle:
        ctx.error("quests", f"prerequisite loop: {' -> '.join(cycle)}")
    if quests and not any(q["type"] == "main" and not q["prerequisites"] for _, q in quests.values()):
        ctx.error("quests", "there must be a main quest with no prerequisites, so the story can start")


# --------------------------------------------------------------------------- input
def _expand(inputs: list[str]) -> list[str]:
    out = []
    for name in inputs:
        out.extend(COMPOSITES.get(name, (name,)))
    return out


def _input_conflicts(actions: list[dict]) -> list[str]:
    problems = []
    for device in ("keyboard_mouse", "gamepad", "touch"):
        for context in ("gameplay", "menu"):
            owners: dict[str, str] = {}
            for action in actions:
                if action["context"] not in (context, "global"):
                    continue
                for name in _expand(action["bindings"][device]):
                    if name in POINTER_INPUTS:
                        continue
                    if name in owners and owners[name] != action["id"]:
                        problems.append(f"{device}: {name!r} is bound to both {owners[name]!r} and {action['id']!r} in {context}")
                    owners[name] = action["id"]
    return problems


@rule
def input_rules(ctx: Ctx) -> None:
    input_file = ctx.single("input_actions.schema.json")
    if input_file is None:
        return
    data = input_file.data
    where = input_file.rel
    actions = data["actions"]
    ids = [a["id"] for a in actions]
    for ident in sorted({i for i in ids if ids.count(i) > 1}):
        ctx.error(where, f"action id {ident!r} is used more than once")
    for required in REQUIRED_INPUT_ACTIONS:
        if required not in ids:
            ctx.error(where, f"missing required action {required!r}")
    for problem in _input_conflicts(actions):
        ctx.error(where, f"binding conflict: {problem}")
    defs = ctx.store.docs["input_actions.schema.json"]["$defs"]
    valid = {
        "keyboard_mouse": set(defs["keyboard_mouse_input"]["enum"]),
        "gamepad": set(defs["gamepad_input"]["enum"]),
        "touch": set(defs["touch_input"]["enum"]),
    }
    by_id = {a["id"]: a for a in actions}
    for preset in data["presets"]:
        patched = {a["id"]: {**a, "bindings": dict(a["bindings"])} for a in actions}
        for override in preset["overrides"]:
            label = f"preset {preset['id']!r}"
            if override["action_id"] not in by_id:
                ctx.error(where, f"{label} changes unknown action {override['action_id']!r}")
                continue
            if not by_id[override["action_id"]]["remappable"]:
                ctx.error(where, f"{label} changes {override['action_id']!r}, which is not remappable")
            for name in override["bindings"]:
                if name not in valid[override["device"]]:
                    ctx.error(where, f"{label}: {name!r} is not a valid {override['device']} input")
            patched[override["action_id"]]["bindings"][override["device"]] = override["bindings"]
        for problem in _input_conflicts(list(patched.values())):
            ctx.error(where, f"preset {preset['id']!r} creates a binding conflict: {problem}")
    for group in ("gamepad", "touch"):
        settings = data[group]
        prefix = "sensitivity" if group == "gamepad" else "ui_scale"
        if not settings[f"{prefix}_min"] <= settings[f"{prefix}_default"] <= settings[f"{prefix}_max"]:
            ctx.error(where, f"{group}: {prefix}_default must sit between {prefix}_min and {prefix}_max")


# --------------------------------------------------------------------------- difficulty
@rule
def difficulty_rules(ctx: Ctx) -> None:
    difficulty = ctx.single("difficulty.schema.json")
    if difficulty is None:
        return
    data = difficulty.data
    where = difficulty.rel
    ids = [m["id"] for m in data["modes"]]
    if sorted(ids) != sorted(["story", "normal", "hard", "challenge"]):
        ctx.error(where, f"modes must be exactly story, normal, hard and challenge, got {ids}")
    for mode in data["modes"]:
        if mode["id"] == "normal":
            for key in ("enemy_damage_mult", "enemy_hp_mult", "telegraph_time_mult", "parry_window_mult", "dodge_window_mult"):
                if mode[key] != 1:
                    ctx.error(where, f"normal mode is the baseline, so {key} must be 1")
        if mode["optional"] != (mode["id"] == "challenge"):
            ctx.error(where, f"mode {mode['id']!r}: only challenge mode is optional")
    offers = data["boss_assist"]["offer_after_failures"]
    order = [offers["tip"], offers["suggested_level"], offers["training_challenge"], offers["support_buff"]]
    if order != sorted(order):
        ctx.error(where, f"boss assists should escalate (tip, level, training, buff), got {order}")
    buff = ctx.get(data["boss_assist"]["support_buff_status_id"])
    if buff is not None and buff["polarity"] != "buff":
        ctx.error(where, "the support buff status must be a buff")


# --------------------------------------------------------------------------- customization & assets
@rule
def customization_rules(ctx: Ctx) -> None:
    custom = ctx.single("customization.schema.json")
    if custom is None:
        return
    data = custom.data
    where = custom.rel
    if data["name_rules"]["min_length"] > data["name_rules"]["max_length"]:
        ctx.error(where, "name_rules min_length is above max_length")
    categories = {c["id"]: c for c in data["categories"]}
    if len(categories) != len(data["categories"]):
        ctx.error(where, "category ids repeat")
    by_category: dict[str, list[dict]] = defaultdict(list)
    for option in data["options"]:
        if option["category"] not in categories:
            ctx.error(where, f"option {option['id']!r} uses undeclared category {option['category']!r}")
        by_category[option["category"]].append(option)
        if option["is_default"] and option["unlock"]["type"] != "starter":
            ctx.error(where, f"default option {option['id']!r} must be a starter unlock")
    for cat_id, category in categories.items():
        options = by_category.get(cat_id, [])
        defaults = [o for o in options if o["is_default"]]
        if not any(o["unlock"]["type"] == "starter" for o in options):
            ctx.error(where, f"category {cat_id!r} needs at least one starter option")
        if category["multi_select"]:
            if len(defaults) > category.get("max_selected", 10):
                ctx.error(where, f"category {cat_id!r} has more defaults than max_selected")
        elif len(defaults) != 1:
            ctx.error(where, f"category {cat_id!r} needs exactly one default option, has {len(defaults)}")


@rule
def asset_rules(ctx: Ctx) -> None:
    used: set[str] = set()

    def collect(node: Any) -> None:
        if isinstance(node, dict):
            for value in node.values():
                collect(value)
        elif isinstance(node, list):
            for value in node:
                collect(value)
        elif isinstance(node, str) and node.startswith("ast_"):
            used.add(node)

    for data_file in ctx.files:
        if data_file.schema_name != "assets.schema.json":
            collect(data_file.data)
    for where, asset in ctx.entries("assets.schema.json"):
        if asset["id"] not in used and asset["kind"] not in GLOBAL_ASSET_KINDS:
            ctx.warn(where, "asset is not used by anything")
