import { BufferGeometry, Group, Line, LineBasicMaterial, Points, PointsMaterial, Vector3 } from "three";
import { FlyLineData, LineStyle } from '../../lib/interface';
import Store from '../../lib/store/store';
export default class FlyLine2d {
    private readonly _config;
    _store: Store;
    _currentData: FlyLineData;
    _currentConfig: LineStyle;
    constructor(store: Store, currentData: FlyLineData);
    createMesh(positionInfo: [Vector3, Vector3]): Group;
    createPathLine: (points: Vector3[]) => Line<BufferGeometry<import("three").NormalBufferAttributes>, LineBasicMaterial>;
    createShader: (points: Vector3[], tadpoleSize: number) => Points<BufferGeometry<import("three").NormalBufferAttributes>, PointsMaterial>;
    createImg(R: number, startAngle: number, endAngle: number): Group;
    create(src: Vector3, dist: Vector3): Group;
}
