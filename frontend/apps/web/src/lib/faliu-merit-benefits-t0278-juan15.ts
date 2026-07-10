export * from "./faliu-merit-benefits-t0278-juan15-base";
export * from "./faliu-merit-benefits-t0278-juan15-equal-buddhas-verses";

import * as t0278Juan15Base from "./faliu-merit-benefits-t0278-juan15-base";
import * as t0278Juan15EqualBuddhasVerses from "./faliu-merit-benefits-t0278-juan15-equal-buddhas-verses";

export const T0278_JUAN_15_MERIT_BENEFITS: FaliuMeritBenefit[] = [
  ...t0278Juan15Base.T0278_JUAN_15_MERIT_BENEFITS,
  ...t0278Juan15EqualBuddhasVerses.T0278_JUAN_15_EQUAL_BUDDHAS_VERSES_MERIT_BENEFITS,
];
