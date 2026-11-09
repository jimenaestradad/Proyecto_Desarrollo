"""Nori economy simulator: coins, XP, pet vitals, shop.

Run (no dependencies, Python 3.9+):
    python3 tool/economy_sim.py main    # A. today-before-the-pass, B. decay only, C. first proposal
    python3 tool/economy_sim.py grid    # sweep decay x care-pack price
    python3 tool/economy_sim.py final   # D = the numbers now in the app, plus the bucket-list
                                        # exploit and "back after a break" checks

Scenario A is the economy as it was on 2026-11-06 (decay 2/h, packs 40-100, accessories 120-180),
kept so changes can be compared against it. Scenario D (FINAL below) is what shipped on 2026-11-07;
when you change prices, decay, coins per habit or the evolution level in the app, change them here
too and rerun `final` before trusting the new numbers. See docs/OPEN_DECISIONS.md, "Economy".

Hour-by-hour over DAYS days, many random seeds per (scenario, player).
Mirrors the shipped rules: lazy linear decay clamped 0-100, coins flat per
difficulty, XP = base * adaptive multiplier (14-day completion rate,
<5 days history -> 1.0), level curve cumulative 50*n*(n-1), care packs of 3.
"""
import math
import random
import statistics as st
from dataclasses import dataclass, field

DAYS = 60
SEEDS = 200
STATS = ("hunger", "hygiene", "love")
BASE_XP = {"easy": 10, "medium": 20, "hard": 30}
ADAPT = {"easy": (0.85, 1.3), "medium": (0.8, 1.2), "hard": (0.87, 1.2)}


@dataclass
class Item:
    stat: str
    price: int  # per pack
    restore: int  # per unit
    grants: int = 3


@dataclass
class Scenario:
    name: str
    decay: float  # points / hour / stat
    coins: dict  # per completion by difficulty
    items: dict  # id -> Item ; first item per stat is tier 1
    accessories: list  # purchasable prices (sunglasses is the free gift)
    starter_items: dict
    starter_coins: int = 0
    bucket_coins: int = 75
    bucket_xp: int = 150
    evolve_level: int = 7


@dataclass
class Player:
    name: str
    habits: list  # difficulties
    p: float  # chance each habit is done on a played day
    checkins: list  # hours of day the app is opened
    skip_day: float = 0.0  # chance the whole day is skipped (app not opened)
    bucket_every: int = 0  # days between completed bucket goals (0 = never)


PLAYERS = [
    Player("light", ["easy", "medium", "medium"], 0.5, [20], bucket_every=30),
    Player("typical", ["easy", "medium", "medium", "medium", "hard"], 0.7, [8, 20], bucket_every=14),
    Player("sporadic", ["easy", "medium", "medium", "medium", "hard"], 0.7, [8, 20], skip_day=0.3, bucket_every=21),
    Player("heavy", ["easy", "easy", "medium", "medium", "medium", "medium", "hard", "hard"], 0.9, [8, 13, 20], bucket_every=10),
]


def level_for(xp):
    n = 1
    while 50 * (n + 1) * n <= xp:
        n += 1
    return n


def adaptive(diff, history):
    if len(history) < 5:
        return 1.0
    window = history[-14:]
    rate = sum(window) / len(window)
    lo, hi = ADAPT[diff]
    t = min(1, max(0, (rate - 0.4) / (0.9 - 0.4)))
    return round(hi - t * (hi - lo), 2)


def tiers(sc, stat):
    return [(k, it) for k, it in sc.items.items() if it.stat == stat]


def run(sc: Scenario, pl: Player, seed: int):
    rng = random.Random(seed)
    vit = {s: 100.0 for s in STATS}
    inv = {k: sc.starter_items.get(k, 0) for k in sc.items}
    coins = sc.starter_coins
    xp = 0
    histories = [[] for _ in pl.habits]
    acc_left = sorted(sc.accessories)
    acc_days = []
    earned = spent_care = spent_acc = 0
    healthy_hours = zero_hours = 0
    level_day = {}
    peak_coins = 0
    t1 = {s: tiers(sc, s)[0] for s in STATS}
    care_per_day = sum(24 * sc.decay / t1[s][1].restore * t1[s][1].price / t1[s][1].grants for s in STATS)

    for day in range(DAYS):
        played = rng.random() >= pl.skip_day
        # Which habits get done today, spread over the day's check-ins.
        done = [played and rng.random() < pl.p for _ in pl.habits]
        for h, d in zip(histories, done):
            h.append(1 if d else 0)
        todo = [i for i, d in enumerate(done) if d]
        rng.shuffle(todo)
        per_checkin = {c: [] for c in pl.checkins}
        for j, i in enumerate(todo):
            per_checkin[pl.checkins[j % len(pl.checkins)]].append(i)
        bucket_today = played and pl.bucket_every and day > 0 and day % pl.bucket_every == 0

        for hour in range(24):
            for s in STATS:
                vit[s] = max(0.0, vit[s] - sc.decay)
            if played and hour in per_checkin:
                # Claims
                for i in per_checkin[hour]:
                    diff = pl.habits[i]
                    mult = adaptive(diff, histories[i][:-1] + [1])
                    xp += round(BASE_XP[diff] * mult)
                    c = sc.coins[diff]
                    coins += c
                    earned += c
                if bucket_today and hour == pl.checkins[-1]:
                    xp += sc.bucket_xp
                    coins += sc.bucket_coins
                    earned += sc.bucket_coins
                # Care -> shop -> care (a caring player)
                for _ in range(2):
                    for s in STATS:
                        for k, it in tiers(sc, s):
                            while inv[k] > 0 and vit[s] <= 100 - 0.8 * it.restore:
                                inv[k] -= 1
                                vit[s] = min(100.0, vit[s] + it.restore)
                    # Keep ~2 days of tier-1 stock per stat; care comes before cosmetics.
                    for s in STATS:
                        k, it = t1[s]
                        stock_pts = sum(inv[kk] * ii.restore for kk, ii in tiers(sc, s))
                        need = 48 * sc.decay
                        while stock_pts < need and coins >= it.price:
                            coins -= it.price
                            spent_care += it.price
                            inv[k] += it.grants
                            stock_pts += it.grants * it.restore
                # Cosmetics: save, keep a 2-day care reserve
                while acc_left and coins - acc_left[0] >= 2 * care_per_day:
                    price = acc_left.pop(0)
                    coins -= price
                    spent_acc += price
                    acc_days.append(day + 1)
            m = min(vit.values())
            healthy_hours += m >= 30
            zero_hours += m <= 0
            peak_coins = max(peak_coins, coins)
        lv = level_for(xp)
        for L in (2, 5, sc.evolve_level):
            if lv >= L and L not in level_day:
                level_day[L] = day + 1

    hours = DAYS * 24
    return dict(
        healthy=healthy_hours / hours,
        zero=zero_hours / hours,
        income=earned / DAYS,
        care_share=spent_care / max(1, earned),
        first_acc=acc_days[0] if acc_days else None,
        acc30=sum(d <= 30 for d in acc_days),
        acc60=len(acc_days),
        all_acc=acc_days[-1] if len(acc_days) == len(sc.accessories) else None,
        end_coins=coins,
        peak=peak_coins,
        lv2=level_day.get(2),
        lv5=level_day.get(5),
        evo=level_day.get(sc.evolve_level),
        care_per_day=care_per_day,
    )


def med(vals):
    vals = [v for v in vals if v is not None]
    return st.median(vals) if vals else None


def summarize(sc, pl, seeds=SEEDS):
    runs = [run(sc, pl, s) for s in range(seeds)]
    pick = lambda k: [r[k] for r in runs]
    share_none = lambda k: sum(r[k] is None for r in runs) / len(runs)
    return dict(
        healthy=st.mean(pick("healthy")),
        zero=st.mean(pick("zero")),
        income=st.mean(pick("income")),
        care_share=st.mean(pick("care_share")),
        first_acc=med(pick("first_acc")),
        no_acc=share_none("first_acc"),
        acc30=st.mean(pick("acc30")),
        acc60=st.mean(pick("acc60")),
        all_acc=med(pick("all_acc")),
        end_coins=med(pick("end_coins")),
        lv2=med(pick("lv2")),
        lv5=med(pick("lv5")),
        evo=med(pick("evo")),
        care_per_day=runs[0]["care_per_day"],
    )


def fmt(v, pct=False, nd=0):
    if v is None:
        return "never"
    if pct:
        return f"{v * 100:.0f}%"
    return f"{v:.{nd}f}"


def table(sc):
    print(f"\n### {sc.name}  (decay {sc.decay}/h, care cost at best tier-1 ~{summarize(sc, PLAYERS[0], 1)['care_per_day']:.0f} coins/day)")
    print("| player | coins/day | pet healthy (all ≥30) | time at 0 | care % of income | 1st bought accessory | accessories by d30 / d60 | coins on d60 | level 2 / 5 / evolve |")
    print("|---|---|---|---|---|---|---|---|---|")
    for pl in PLAYERS:
        r = summarize(sc, pl)
        print(f"| {pl.name} | {r['income']:.0f} | {fmt(r['healthy'], True)} | {fmt(r['zero'], True)} | "
              f"{fmt(r['care_share'], True)} | day {fmt(r['first_acc'])} | {r['acc30']:.1f} / {r['acc60']:.1f} of {len(sc.accessories)} | "
              f"{fmt(r['end_coins'])} | d{fmt(r['lv2'])} / d{fmt(r['lv5'])} / d{fmt(r['evo'])} |")


CURRENT_ITEMS = {
    "food": Item("hunger", 50, 25), "cake": Item("hunger", 90, 45),
    "shampoo": Item("hygiene", 40, 25), "hair-brush": Item("hygiene", 70, 45),
    "plushie": Item("love", 60, 20), "blanket": Item("love", 100, 40),
}
CURRENT_ACC = [120, 130, 160, 180, 180]  # sunglasses (140) is the free first-completion gift
CURRENT_STARTER = {"food": 3, "shampoo": 2, "plushie": 1}
COINS_5_10_15 = {"easy": 5, "medium": 10, "hard": 15}

CURRENT = Scenario("A. Today", 2.0, COINS_5_10_15, CURRENT_ITEMS, CURRENT_ACC, CURRENT_STARTER)


def proposed(decay=1.0, t1=15, t2=25, r1=25, r2=50, acc=(100, 150, 150, 200, 250), coins=COINS_5_10_15,
             starter=None, name="C. Proposed", bucket_coins=50, evolve=5):
    items = {
        "food": Item("hunger", t1, r1), "cake": Item("hunger", t2, r2),
        "shampoo": Item("hygiene", t1, r1), "hair-brush": Item("hygiene", t2, r2),
        "plushie": Item("love", t1, r1), "blanket": Item("love", t2, r2),
    }
    starter = starter if starter is not None else {"food": 3, "shampoo": 3, "plushie": 3}
    return Scenario(name, decay, coins, items, list(acc), starter, bucket_coins=bucket_coins, evolve_level=evolve)


if __name__ == "__main__":
    import sys
    mode = sys.argv[1] if len(sys.argv) > 1 else "main"
    if mode == "main":
        table(CURRENT)
        table(Scenario("B. Today, decay 0.75/h only", 0.75, COINS_5_10_15, CURRENT_ITEMS, CURRENT_ACC, CURRENT_STARTER))
        table(proposed())
    elif mode == "grid":
        # Sweep decay x tier-1 pack price, everything else as proposed.
        print("decay | t1 price | light healthy | sporadic healthy | typical 1st acc | typical acc d60 | heavy all-acc day | heavy coins d60")
        for decay in (0.5, 0.75, 1.0, 1.25, 1.5, 2.0):
            for t1 in (10, 15, 20, 30, 45):
                sc = proposed(decay=decay, t1=t1, t2=round(t1 * 1.7))
                L = summarize(sc, PLAYERS[0], 60)
                S = summarize(sc, PLAYERS[2], 60)
                T = summarize(sc, PLAYERS[1], 60)
                H = summarize(sc, PLAYERS[3], 60)
                print(f"{decay} | {t1} | {fmt(L['healthy'], True)} | {fmt(S['healthy'], True)} | d{fmt(T['first_acc'])} | "
                      f"{T['acc60']:.1f} | d{fmt(H['all_acc'])} | {fmt(H['end_coins'])}")


FINAL = proposed(decay=1.0, t1=10, t2=18, r1=25, r2=50, acc=(100, 180, 250, 350, 500),
                 name="D. Recommended", bucket_coins=50, evolve=5)


def final_mode():  # prints the tables for FINAL
    table(FINAL)
    # Evolution at level 7 instead of 5, same economy (XP side only).
    lv7 = proposed(decay=1.0, t1=10, t2=18, r1=25, r2=50, acc=(100, 180, 250, 350, 500),
                   name="D at level-7 evolution", bucket_coins=50, evolve=7)
    print("\nEvolution day at level 7 instead of 5:")
    for pl in PLAYERS:
        print(f"  {pl.name}: day {fmt(summarize(lv7, pl, 60)['evo'])}")

    # Bucket-list abuse: typical habits + one self-paid goal every day.
    print("\nBucket-list exploit (typical player + 1 fake goal/day):")
    abuser = Player("abuser", PLAYERS[1].habits, 0.7, [8, 20], bucket_every=1)
    for sc, coins, label in ((CURRENT, 250, "today, typed reward at the 250 cap"),
                             (FINAL, 100, "fixed sizes, 'big' = 100, unlimited"),
                             (FINAL, 100 * 2 / 7, "fixed sizes, at most 2 paid goals/week")):
        s2 = Scenario(sc.name, sc.decay, sc.coins, sc.items, sc.accessories, sc.starter_items,
                      bucket_coins=coins, evolve_level=sc.evolve_level)
        r = summarize(s2, abuser, 60)
        print(f"  {label}: {r['income']:.0f} coins/day, all accessories by day {fmt(r['all_acc'])}")

    # Coming back after a week away: all three vitals at 0, buy enough to refill.
    print("\nRefill all three vitals from 0 to 100 (cheapest items):")
    for sc in (CURRENT, FINAL):
        cost = 0
        for s in STATS:
            k, it = tiers(sc, s)[0]
            units = math.ceil(100 / it.restore)
            cost += math.ceil(units / it.grants) * it.price
        print(f"  {sc.name}: {cost} coins (~{cost / 38:.1f} days of a typical player's coins)")
    print("\nHours from 100 to the 'Pet needs you' line (30):",
          {sc.name: round(70 / sc.decay) for sc in (CURRENT, FINAL)})


if __name__ == "__main__" and len(__import__("sys").argv) > 1 and __import__("sys").argv[1] == "final":
    final_mode()
