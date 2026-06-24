import type { FaliuMeritBenefit } from "./faliu-merit-benefits";
import { T0276_JUAN_1_OPENING_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-opening";
import { T0276_JUAN_1_SHUOFAPIN_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-shuofapin";
import { T0276_JUAN_1_SHIGONGDE_OPENING_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-shigongde-opening";
import { T0276_JUAN_1_SHIGONGDE_FIRST_FOUR_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-shigongde-first-four";
import { T0276_JUAN_1_SHIGONGDE_FIFTH_TO_SEVENTH_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-shigongde-fifth-to-seventh";
import { T0276_JUAN_1_SHIGONGDE_EIGHTH_TO_TENTH_MERIT_BENEFITS } from "./faliu-merit-benefits-t0276-shigongde-eighth-to-tenth";

export const T0276_JUAN_1_MERIT_BENEFITS: FaliuMeritBenefit[] = [
  ...T0276_JUAN_1_OPENING_MERIT_BENEFITS,
  ...T0276_JUAN_1_SHUOFAPIN_MERIT_BENEFITS,
  ...T0276_JUAN_1_SHIGONGDE_OPENING_MERIT_BENEFITS,
  ...T0276_JUAN_1_SHIGONGDE_FIRST_FOUR_MERIT_BENEFITS,
  ...T0276_JUAN_1_SHIGONGDE_FIFTH_TO_SEVENTH_MERIT_BENEFITS,
  ...T0276_JUAN_1_SHIGONGDE_EIGHTH_TO_TENTH_MERIT_BENEFITS,
];
