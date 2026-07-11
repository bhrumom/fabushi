export * from "./faliu-merit-benefits-t0278-juan16-base";
export * from "./faliu-merit-benefits-t0278-juan16-drink-through-seats";

import * as t0278Juan16Base from "./faliu-merit-benefits-t0278-juan16-base";
import * as t0278Juan16DrinkThroughSeats from "./faliu-merit-benefits-t0278-juan16-drink-through-seats";

export const T0278_JUAN_16_MERIT_BENEFITS: FaliuMeritBenefit[] = [
  ...t0278Juan16Base.T0278_JUAN_16_BASE_MERIT_BENEFITS,
  ...t0278Juan16DrinkThroughSeats.T0278_JUAN_16_DRINK_THROUGH_SEATS_MERIT_BENEFITS,
];
