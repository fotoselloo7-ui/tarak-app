// Oyunun kullandığı Three.js sınıfları (kullanılmayanlar pakete girmez).
export {
  WebGLRenderer, Scene, PerspectiveCamera, Group, Mesh, InstancedMesh, Object3D,
  BoxGeometry, SphereGeometry, CylinderGeometry, ConeGeometry, CapsuleGeometry, TorusGeometry,
  PlaneGeometry, CircleGeometry, ExtrudeGeometry, TubeGeometry, ShapeGeometry,
  Shape, Path, Vector2, Vector3, Color, CatmullRomCurve3, QuadraticBezierCurve3,
  MeshStandardMaterial, MeshLambertMaterial, MeshBasicMaterial, MeshPhysicalMaterial, Texture,
  HemisphereLight, DirectionalLight, Fog, CanvasTexture, RepeatWrapping,
  SRGBColorSpace, DoubleSide, DynamicDrawUsage, BufferAttribute,
  IcosahedronGeometry, PMREMGenerator, ACESFilmicToneMapping, PCFShadowMap, PCFSoftShadowMap, BackSide,
  WebGLRenderTarget, HalfFloatType, Scene as Sahne,
  BufferGeometry, Points, PointsMaterial, LineSegments, LineBasicMaterial,
  NeutralToneMapping, AdditiveBlending, MeshToonMaterial, NearestFilter, DataTexture, RedFormat, ShaderChunk, Material
} from 'three';
export { Sky } from 'three/addons/objects/Sky.js';
export { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
export { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
export { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
export { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
export { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
export { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
export { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
