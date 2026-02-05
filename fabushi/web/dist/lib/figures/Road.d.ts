import { RoadStyle } from '../../lib/interface';
import Store from '../../lib/store/store';
import { BufferGeometry, Group, Line, LineBasicMaterial, Points, PointsMaterial, Quaternion, Vector2, Vector3 } from "three";
export declare class Road {
    private readonly _config;
    _store: Store;
    _currentData: {
        path: Vector3[];
        style?: Partial<RoadStyle>;
    };
    _currentConfig: RoadStyle;
    tadpolePointsMesh: Points;
    points: Vector3[];
    tadpoleSize: number;
    constructor(store: Store, currentData: {
        path: Vector3[];
        style?: Partial<RoadStyle>;
    });
    calculateRoadPath: (points: Vector3[]) => Group;
    calculateRoadPath2D: (points: Vector3[]) => void;
    calculateArcPath: (points: Vector3[]) => void;
    createShader: (points: Vector3[]) => Points<BufferGeometry<import("three").NormalBufferAttributes>, PointsMaterial>;
    createMesh(points: Vector3[]): Group;
    generateLinePoints: (points: Vector2[], quaternion: Quaternion) => Vector3[];
    createPath: (points: Vector3[]) => Line<BufferGeometry<import("three").NormalBufferAttributes>, LineBasicMaterial>;
    roadPathLine3D: (startDeg: number, endDeg: number) => Vector2[];
    roadPathLine2D: (start: Vector3, end: Vector3) => void;
    create(points: Vector3[]): Group;
}
