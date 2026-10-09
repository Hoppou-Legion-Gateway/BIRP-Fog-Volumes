using UnityEngine;

namespace Sinnwrig.FogVolumes
{
    /// <summary>
    /// Writes material values only when they differ, and tracks whether anything changed.
    /// Lets volumes refresh their materials freely without needlessly dirtying the scene.
    /// </summary>
    internal struct MaterialWriter
    {
        private readonly Material material;

        public bool Changed { get; private set; }


        public MaterialWriter(Material material)
        {
            this.material = material;
            Changed = false;
        }


        public void SetFloat(string name, float value)
        {
            if (material.GetFloat(name) == value)
                return;

            material.SetFloat(name, value);
            Changed = true;
        }


        public void SetVector(string name, Vector4 value)
        {
            if (material.GetVector(name) == value)
                return;

            material.SetVector(name, value);
            Changed = true;
        }


        public void SetTexture(string name, Texture value)
        {
            if (material.GetTexture(name) == value)
                return;

            material.SetTexture(name, value);
            Changed = true;
        }


        public void SetKeyword(string keyword, bool enabled)
        {
            if (material.IsKeywordEnabled(keyword) == enabled)
                return;

            if (enabled)
                material.EnableKeyword(keyword);
            else
                material.DisableKeyword(keyword);

            Changed = true;
        }


        public void SetPassEnabled(string lightMode, bool enabled)
        {
            if (material.GetShaderPassEnabled(lightMode) == enabled)
                return;

            material.SetShaderPassEnabled(lightMode, enabled);
            Changed = true;
        }
    }
}
