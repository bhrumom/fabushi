import { Coordinates, ScatterStyle } from '../../lib/interface';
import { Group, Mesh, MeshBasicMaterial, PlaneGeometry } from "three";
import Store from '../../lib/store/store';
export default class Scatter {
    private readonly _config;
    private readonly _store;
    _currentStyle: ScatterStyle;
    _currentData: Coordinates | undefined;
    constructor(store: Store);
    setMeshAttr(geometry: PlaneGeometry, material: MeshBasicMaterial, { lon, lat, ...rest }: Coordinates): {
        mesh: Mesh<PlaneGeometry, MeshBasicMaterial>;
        size: number;
    };
    createScatterMesh: (data: Coordinates) => Mesh<PlaneGeometry, MeshBasicMaterial>;
    createScatter(): {
        geometry: PlaneGeometry;
        material: MeshBasicMaterial;
    };
    createPointMesh: (data: Coordinates) => Mesh<PlaneGeometry, MeshBasicMaterial>;
    createPoint(): {
        geometry: PlaneGeometry;
        material: MeshBasicMaterial;
    };
    createCustomMesh: (data: Coordinates) => Mesh<PlaneGeometry, MeshBasicMaterial>;
    createCustom(): {
        geometry: PlaneGeometry;
        material: MeshBasicMaterial;
    };
    create(data: Coordinates): Group;
}
