import { Object3D, Raycaster, Renderer, Vector2 } from "three";
import { DragConfig } from '../../lib/interface';
export default class EarthController {
    earth: Object3D;
    isDragging: boolean;
    previousMousePosition: {
        x: number;
        y: number;
    };
    raycaster: Raycaster;
    options: DragConfig;
    rotationVelocity: {
        x: number;
        y: number;
    };
    mouse: Vector2;
    constructor(earth: Object3D, renderer: Renderer, options: Partial<DragConfig>);
    onMouseDown(event: MouseEvent): void;
    onMouseMove(event: MouseEvent): void;
    onMouseUp(event: MouseEvent): void;
    isDraggingEarth(event: MouseEvent): boolean;
    update(): void;
}
