"""Entry: --smoke runs headless steps, else M1 playtest arena."""
from __future__ import annotations
import sys
from engine.movement import MoveState, update
from engine.math2d import Vec2
from engine.waves import budget
from engine.loop import FixedAccumulator
from engine.feel import Feel
from game.arena import collide, PILLARS, W, H

def smoke() -> int:
    s = MoveState(); f = Feel(); acc = FixedAccumulator()
    # simulate: dash, slide, jump, slam sequence + arena collide
    for i in range(600):
        wish = Vec2(1, 0.3)
        frozen = f.update(1/60)
        if frozen: continue
        evt = update(s, wish, 1/60,
                     want_dash=(i == 10),
                     want_slide=(20 <= i < 60),
                     want_jump=(i in (25, 70)),
                     want_slam=(i == 120))
        if s.dash_t > 0 or s.sliding: f.push_trail(s.pos.x, s.pos.y)
        if evt == "slammed":
            f.add_trauma(0.5); f.trigger_hitstop(0.04)
        collide(s.pos, s.vel)
        _ = budget(i/60)
    assert 0 <= s.pos.x <= W and 0 <= s.pos.y <= H, "arena clamp failed"
    print(f"smoke ok pos=({s.pos.x:.1f},{s.pos.y:.1f}) z={s.z:.1f} stamina={s.stamina:.2f} trail={len(f.trail)}")
    return 0

def main() -> int:
    if "--smoke" in sys.argv:
        return smoke()
    try:
        import pygame
    except ImportError:
        print("pygame-ce not installed. Run: pip install -r requirements.txt")
        return 2
    pygame.init()
    screen = pygame.display.set_mode((960, 600))
    pygame.display.set_caption("SERAPHONK M1 — WASD move, SHIFT dash, SPACE jump, CTRL slide/slam")
    font = pygame.font.SysFont("consolas", 16)
    from engine.movement import MoveState as MS, update as upd
    from engine.math2d import Vec2 as V
    st = MS(); feel = Feel(); acc = FixedAccumulator()
    clock = pygame.time.Clock(); running = True
    prev_dash = prev_jump = False
    # start center
    st.pos = V(W/2, H/2)
    while running:
        raw_dt = clock.tick(60) / 1000.0
        for e in pygame.event.get():
            if e.type == pygame.QUIT: running = False
        keys = pygame.key.get_pressed()
        wish = V((keys[pygame.K_d]-keys[pygame.K_a]), (keys[pygame.K_s]-keys[pygame.K_w]))
        dash_edge = bool(keys[pygame.K_LSHIFT] or keys[pygame.K_RSHIFT]) and not prev_dash
        jump_edge = bool(keys[pygame.K_SPACE]) and not prev_jump
        prev_dash = bool(keys[pygame.K_LSHIFT] or keys[pygame.K_RSHIFT])
        prev_jump = bool(keys[pygame.K_SPACE])
        slide_held = bool(keys[pygame.K_LCTRL] or keys[pygame.K_RCTRL])
        want_slam = slide_held and st.airborne
        frozen = feel.update(raw_dt)
        if not frozen:
            for _ in range(acc.frames(raw_dt)):
                evt = upd(st, wish, acc.step, want_dash=dash_edge, want_slide=slide_held,
                          want_slam=want_slam, want_jump=jump_edge)
                dash_edge = jump_edge = False  # edge consumed
                if st.dash_t > 0 or st.sliding: feel.push_trail(st.pos.x, st.pos.y)
                if evt == "slammed":
                    feel.add_trauma(0.55); feel.trigger_hitstop(0.045)
                collide(st.pos, st.vel)
                if st.airborne and st.z <= 0.01 and st.vz < -600:
                    feel.add_trauma(0.15)
        # camera + shake
        sh = feel.shake()
        cx, cy = int(480 - st.pos.x*0.5 + sh*0.5), int(300 - st.pos.y*0.5 - st.z*0.3 + sh*0.3)
        screen.fill((10, 10, 18))
        # arena bounds
        pygame.draw.rect(screen, (30, 30, 50), (cx, cy, int(W*0.5), int(H*0.5)), 2)
        for p in PILLARS:
            pygame.draw.circle(screen, (60, 60, 90), (int(cx+p.x*0.5), int(cy+p.y*0.5)), int(p.r*0.5))
        for tx, ty, age in feel.trail:
            a = max(0, min(255, int(age/0.35*120)))
            pygame.draw.circle(screen, (120, 180, 255), (int(cx+tx*0.5), int(cy+ty*0.5)), 10, 1)
        px, py = int(cx+st.pos.x*0.5), int(cy+st.pos.y*0.5 - st.z*0.3)
        col = (150, 200, 255) if st.iframes_t > 0 else (255, 230, 150)
        if st.slamming: col = (255, 120, 120)
        pygame.draw.circle(screen, col, (px, py), 14)
        pygame.draw.circle(screen, (255, 255, 255), (px, py), 18, 2)  # halo
        hud = f"stam {st.stamina:.1f} {'DASH' if st.dash_t>0 else ''} {'SLIDE' if st.sliding else ''} {'AIR' if st.airborne else ''} z={st.z:.0f}"
        screen.blit(font.render(hud, True, (220, 220, 240)), (10, 10))
        screen.blit(font.render("WASD move | SHIFT dash | SPACE jump | CTRL slide (air=slam)", True, (150, 150, 170)), (10, 578))
        pygame.display.flip()
    pygame.quit()
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
