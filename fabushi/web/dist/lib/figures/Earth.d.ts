import { Group, Mesh, MeshPhongMaterial, SphereGeometry } from "three";
import Store from '../../lib/store/store';
declare class CreateEarth {
    materialMap: Record<string, any>;
    private _config;
    private _store;
    constructor(store: Store);
    createSphereMesh(): Mesh<SphereGeometry, any>;
    createTextureSphereMesh(): Mesh<SphereGeometry, MeshPhongMaterial>;
    create(): Group;
}
export default CreateEarth;
