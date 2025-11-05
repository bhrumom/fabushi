import { BufferGeometry, Group, Points, PointsMaterial, Vector3 } from "three";
import { Line2 } from "three/examples/jsm/lines/Line2";
import { FlyLineData, LineStyle } from '../../lib/interface';
import Store from '../../lib/store/store';
export default class FlyLine3d {
    private readonly _config;
    _store: Store;
    _currentData: FlyLineData;
    _currentConfig: LineStyle;
    constructor(store: Store, currentData: FlyLineData);
    createMesh(positionInfo: [Vector3, Vector3]): Group;
    createImg(R: number, startAngle: number, endAngle: number): Group;
    createPathLine: (middlePos: Vector3, r: number, startDeg: number, endDeg: number) => Line2;
    createShader: (r: number, startAngle: number, endAngle: number) => Points<BufferGeometry<import("three").NormalBufferAttributes>, PointsMaterial>;
    create(src: Vector3, dist: Vector3): Group;
}
