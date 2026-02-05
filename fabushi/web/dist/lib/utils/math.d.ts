import { Quaternion, Vector3 } from "three";
import { Coordinates3D } from '../../lib/interface';
/**
 * 经纬度坐标转球面坐标
 * @param {地球半径} R
 * @param {经度(角度值)} longitude
 * @param {维度(角度值)} latitude
 */
declare const lon2xyz: (R: number, longitude: number, latitude: number, offset?: number) => Coordinates3D;
declare const _3Dto2D: (start: Vector3, end: Vector3) => {
    quaternion: Quaternion;
    startPoint3D: Vector3;
    endPoint3D: Vector3;
};
declare const radianAOB: (A: Vector3, B: Vector3, O: Vector3) => number;
declare const threePointCenter: (p1: Vector3, p2: Vector3, p3: Vector3) => Vector3;
declare function getFunctionExpression(src: Vector3, dist: Vector3): Vector3;
declare function getPointByDistance(x1: number, y1: number, k: number, b: number, s: number): Vector3;
declare function uuid(): string;
declare function getScale(data: number[], base: number): number;
export { lon2xyz, _3Dto2D, radianAOB, threePointCenter, getFunctionExpression, getPointByDistance, uuid, getScale, };
