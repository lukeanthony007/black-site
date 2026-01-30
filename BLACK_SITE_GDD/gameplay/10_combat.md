# Combat System

Counter-Strike gunfeel with gesture-based melee.

---

## 14. Gunplay System

### No Crosshair Implementation

- Screen center is the aim reference (invisible)
- Shooting guided by recoil, sway, tracers/impacts, sound, and discipline—not UI
- Precision is earned through recoil control and stabilization

### Accuracy Model

```
Spread = base + movement + airborne + parkour_multipliers + firing_bloom
```

| Factor | Effect |
|--------|--------|
| Movement speed | Higher speed → more spread |
| Airborne state | Significant spread penalty |
| Parkour actions | Roll/slide/wallrun multipliers |
| Sustained firing | Bloom accumulation |
| Recent landing | Brief instability |
| Recovery | Spread decreases when stabilizing |

### Recoil Model

- Per-weapon recoil patterns (vertical + horizontal)
- Camera kick (view displacement)
- Weapon kick (viewmodel animation)
- Dual-wield: independent recoil tracking per hand

### Dual Wield System

**Two independent hand slots: Left Hand + Right Hand**

| Attribute | Per-Hand |
|-----------|----------|
| Equipped item | Gun / melee / empty |
| Ammo pool | Independent |
| Fire cooldown | Independent |
| Reload state | Independent |
| Recoil state | Independent |

**Two-handed weapons** (rifles, some melee) occupy both slots.

### Pickups

- **E to pick up** (context-sensitive)
- If hand empty → auto-equip there
- If both hands full → swap with chosen hand (tap 1/2) or drop current (G)

### Weapon Categories

| Category | Examples | Hands | Notes |
|----------|----------|-------|-------|
| Pistol | 9mm, .45 | 1 | Suppressible |
| SMG | MP5, Uzi | 1 | High ROF, spread |
| Rifle | AK, M4 | 2 | Accuracy, power |
| Shotgun | Pump, auto | 2 | Devastating close |
| Knife | Combat knife | 1 | Silent takedowns |
| Katana | Traditional | 2 | Long arcs, high damage |
| Throwing knife | Consumable | 1 | Silent ranged |

---

## 15. Melee System (Gesture-Based)

### Input Model

| Input | Action |
|-------|--------|
| Left click | Right hand action |
| Right click | Left hand action |
| Tap click (gun) | Fire weapon |
| Hold modifier + click + mouse swing | Gesture melee |

**Melee Modifier** (recommended: Mouse4 or Q):
- While held: click + mouse swing = melee attack for that hand
- Without modifier: click fires gun normally (supports automatic fire)

### Gesture Detection

While melee modifier held:
1. Track mouse delta vector and speed during swing window
2. Map to attack direction: Left→Right, Right→Left, Overhead, Thrust
3. Calculate intensity based on speed (clamped)
4. Execute capsule/box sweep along attack arc
5. Apply damage + stagger + impulse

### Weapon-Dependent Melee

| Weapon | Attack Type | Damage | Noise | Speed |
|--------|-------------|--------|-------|-------|
| Empty hand | Punch | Low | Low | Fast |
| Gun | Gun-bash/buttstroke | Medium | Medium | Medium |
| Knife | Stab/slash | High | Low | Fast |
| Katana | Heavy slash | Very high | Medium | Slow |

### Hit Reactions

- Stagger (brief incapacitation)
- Knockback (physics impulse)
- Blood effects (decals + particles)
- Ragdoll on death

---

