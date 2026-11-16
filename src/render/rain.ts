import * as THREE from 'three'

export function rainGlass() {
  const mat = new THREE.ShaderMaterial({
    transparent: true,
    depthWrite: false,
    uniforms: {
      uTime: { value: 0 },
      uRain: { value: 1 },
    },
    vertexShader: `
      varying vec3 vW;
      varying vec3 vN;
      void main() {
        vec4 world = modelMatrix * vec4(position, 1.0);
        vW = world.xyz;
        vN = mat3(modelMatrix) * normal;
        gl_Position = projectionMatrix * viewMatrix * world;
      }
    `,
    fragmentShader: `
      varying vec3 vW;
      varying vec3 vN;
      uniform float uTime;
      uniform float uRain;
      void main() {
        vec3 n = normalize(vN);
        float pane = abs(n.z) + abs(n.x);
        float column = fract(sin(floor(vW.x * 16.0 + vW.z * 16.0) * 12.9898) * 43758.5453);
        float streak = smoothstep(0.78, 0.97, column);
        float flow = fract(vW.y * 1.7 - uTime * 0.28);
        float drip = streak * smoothstep(0.0, 0.12, flow) * smoothstep(0.9, 0.25, flow);
        float dropSeed = fract(sin(dot(floor(vW.xy * vec2(26.0, 11.0) + vW.z * 8.0), vec2(127.1, 311.7))) * 43758.5453);
        float drop = smoothstep(0.72, 1.0, dropSeed);
        float fall = fract(vW.y * 4.0 - uTime * 0.08 + dropSeed);
        drop *= smoothstep(0.22, 0.0, abs(fall - 0.35));
        float water = clamp((drip * 0.85 + drop) * uRain, 0.0, 1.0);
        vec3 tint = mix(vec3(0.55, 0.72, 0.88), vec3(0.9, 0.95, 1.0), water);
        float alpha = (0.18 + water * 0.62) * clamp(pane, 0.35, 1.0);
        gl_FragColor = vec4(tint, alpha);
      }
    `,
  })
  mat.userData.rain = true
  return mat
}

export function touchRain(root: THREE.Object3D, time: number) {
  root.traverse((obj) => {
    const mesh = obj as THREE.Mesh
    const mat = mesh.material as THREE.ShaderMaterial | undefined
    if (mat && mat.userData?.rain && mat.uniforms?.uTime) mat.uniforms.uTime.value = time
  })
}
