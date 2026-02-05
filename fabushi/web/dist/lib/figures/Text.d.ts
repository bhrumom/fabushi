import Store from '../../lib/store/store';
import { Object3D, Vector3 } from "three";
import { LessCoordinate, TextStyle } from '../../lib/interface';
export default class CountryNamesText {
    constructor(store: Store);
    private _store;
    countryData: {
        text: string;
        position: LessCoordinate;
        style: TextStyle;
    }[];
    generateCountryData(): {
        text: string;
        position: Vector3;
        style: {
            fontSize: number;
            color: string;
        } & {
            fontSize: number;
            color: string;
        };
    }[];
    init(): Object3D<import("three").Event>[];
    create(): Object3D<import("three").Event>[];
}
