# Starbase Water Drop Sim
barges = 25
water_day = barges * 6000  # m³
plastic_day = barges * 20  # tons
fuel = plastic_day * 0.5
carbon = plastic_day * 0.4
profit_day = (6196293 * barges) + (fuel * 500) + (carbon * 250)
profit_year = profit_day * 365

print("Starbase Sim")
print("============")
print(f"Daily: {water_day:,} m³ water | {fuel:.0f} tons fuel | {carbon:.0f} tons carbon")
print(f"Profit: ${profit_day:,.2f}/day")
print(f"Yearly: ${profit_year:,.2f}")
print("#StarSalt #OceanClean")
