export * from "./faliu-merit-benefits-t0278-juan15-base";
export * from "./faliu-merit-benefits-t0278-juan15-equal-buddhas-verses";
export * from "./faliu-merit-benefits-t0278-juan15-to-all-places-opening";

import * as t0278Juan15Base from "./faliu-merit-benefits-t0278-juan15-base";
import * as t0278Juan15EqualBuddhasVerses from "./faliu-merit-benefits-t0278-juan15-equal-buddhas-verses";
import * as t0278Juan15ToAllPlacesOpening from "./faliu-merit-benefits-t0278-juan15-to-all-places-opening";

export const T0278_JUAN_15_MERIT_BENEFITS: FaliuMeritBenefit[] = [
  ...t0278Juan15Base.T0278_JUAN_15_MERIT_BENEFITS,
  ...t0278Juan15EqualBuddhasVerses.T0278_JUAN_15_EQUAL_BUDDHAS_VERSES_MERIT_BENEFITS,
  ...t0278Juan15ToAllPlacesOpening.T0278_JUAN_15_TO_ALL_PLACES_OPENING_MERIT_BENEFITS,
];
