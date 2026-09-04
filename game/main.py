"""Entry: --smoke runs 300 headless steps, else opens window if pygame present."""
from __future__ import annotations
import sys
from engine.movement import MoveState, update
from engine.math2d import Vec2
from engine.waves import budget

def smoke() -> int:
    s = MoveState()
    for i in range(300):
        wish = Vec2(1, 0.3)
        update(s, wish, 1/60, want_dash=(i == 10), want_slide=(20 <= i < 60))
        _ = budget(i/60)
    print(f"smoke ok pos=({s.pos.x:.1f},{s.pos.y:.1f}) stamina={s.stamina:.2f}")
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
    pygame.display.set_caption("SERAPHONK M1 movement")
    from engine.movement import MoveState as MS, update as upd
    from engine.math2d import Vec2 as V
    st = MS(); clock = pygame.time.Clock(); running = True
    while running:
        dt = clock.tick(60) / 1000.0
        for e in pygame.event.get():
            if e.type == pygame.QUIT: running = False
        keys = pygame.key.get_pressed()
        wish = V((keys[pygame.K_d]-keys[pygame.K_a]), (keys[pygame.K_s]-keys[pygame.K_w]))
        upd(st, wish, min(dt, 1/30), want_dash=keys[pygame.K_LSHIFT], want_slide=keys[pygame.K_LCTRL])
        screen.fill((10, 10, 18))
        pygame.draw.circle(screen, (255, 230, 150), (int(480+st.pos.x*0.2), int(300+st.pos.y*0.2)), 14)
        pygame.display.flip()
    pygame.quit()
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
