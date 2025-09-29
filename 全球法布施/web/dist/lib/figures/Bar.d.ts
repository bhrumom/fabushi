import { BarData, BarStyle } from '../../lib/interface';
import Store from '../../lib/store/store';
import { Mesh } from "three";
export default class Bar {
    private readonly _config;
    _store: Store;
    _currentData: BarData;
    _commonStyle: BarStyle;
    constructor(store: Store);
    createMesh: (data: BarData[]) => Mesh;
    getCurrentStyle: (data: BarData) => BarStyle;
    create(data: BarData[]): Mesh<import("three").BufferGeometry<import("three").NormalBufferAttributes>, import("three").Material | import("three").Material[]>;
}
