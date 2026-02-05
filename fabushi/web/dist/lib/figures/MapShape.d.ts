import { Options, RegionBaseStyle } from '../../lib/interface';
import { BufferGeometry, Group, LineBasicMaterial, LineLoop, Mesh, MeshPhongMaterial } from "three";
import { Feature, Position } from "geojson";
import ChartScene from '../../lib/chartScene';
export default class MapShape {
    private readonly _config;
    wallPoints: Record<string, any>;
    currentStyle: RegionBaseStyle;
    features: Feature[];
    geometryArr: BufferGeometry[];
    _options: Options;
    constructor(chartScene: ChartScene);
    create(): Group[];
    create2d(countryCoordinates: Position[][][]): {
        lineArr: LineLoop<BufferGeometry<import("three").NormalBufferAttributes>, import("three").Material | import("three").Material[]>[];
    };
    create3d(countryCoordinates: Position[][][]): {
        lineArr: LineLoop<BufferGeometry<import("three").NormalBufferAttributes>, import("three").Material | import("three").Material[]>[];
    };
    createShapeGeometry(usefulIndexArr: number[], points: number[]): BufferGeometry<import("three").NormalBufferAttributes>;
    createLineMesh(points: number[]): LineLoop<BufferGeometry<import("three").NormalBufferAttributes>, LineBasicMaterial>;
    mergeGeometry(): Mesh<BufferGeometry<import("three").NormalBufferAttributes>, MeshPhongMaterial>;
    gridPoint(polygon: Position[]): {
        linePoints3d: number[];
        allPoints3d: number[];
        linePoints2d: number[];
        usefulIndexArr: number[];
        allPoints2d: number[];
    };
    minMax(arr: number[]): number[];
    compareNum(num1: number, num2: number): 0 | 1 | -1;
    pointInPolygon(point: number[], polygon: Position[]): boolean;
    trianglePlan(polygonPointsArr: Position[], polygon: Position[]): number[];
    getCurrentStyle(name: string): void;
}
