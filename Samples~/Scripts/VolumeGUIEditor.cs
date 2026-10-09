using System;
using System.Linq;
using System.Collections.Generic;

using UnityEngine;
using UnityEngine.SceneManagement;

using Sinnwrig.FogVolumes;


public class VolumeGUIEditor : MonoBehaviour
{
    private static string[] sceneNames;
    private static int selectedSceneIndex;

    static List<FogVolume> sceneVolumes;


    static void RefreshProps()
    {
        sceneVolumes = FindObjectsOfType<FogVolume>(true).ToList();
    }


    [RuntimeInitializeOnLoadMethod]
    static void InitVolumeGUI()
    {
        // Get the names of all scenes in the build settings
        sceneNames = new string[SceneManager.sceneCountInBuildSettings];
        for (int i = 0; i < sceneNames.Length; i++)
            sceneNames[i] = System.IO.Path.GetFileNameWithoutExtension(SceneUtility.GetScenePathByBuildIndex(i));

        selectedSceneIndex = SceneManager.GetActiveScene().buildIndex;
    }


    // GUI properties
    static string selectedTab = "Volume";
    static string[] tabNames = { "Volume", "Rendering", "Scene", "Camera" };
    static Rect editorRect = new Rect(10, 10, 350, 400);


    // Camera properties
    bool flying = false, camLocked = true;
    Vector3 flyPos, defaultPos;
    Quaternion flyRot, defaultRot;

    static float mainSpeed = 15; 
    static float shiftSpeed = 3;
    static float camSens = 0.5f;


    static int frameCounter;
    static float timeCounter;
    static int lastFps;
    static float avgTime;


    const float sampleTime = 0.25f;


    static void GetFrameCount()
    {   
        if (timeCounter < sampleTime)
        {
            frameCounter++;
            timeCounter += Time.deltaTime;
        }
        else
        {
            lastFps = (int)(frameCounter / sampleTime);
            avgTime = (timeCounter / frameCounter) * 1000;

            timeCounter = 0;
            frameCounter = 0;
        }
    }


    void Start()
    {
        RefreshProps();

        var main = Camera.main.gameObject;

        defaultPos = main.transform.position;
        defaultRot = main.transform.rotation;
        flyPos = defaultPos;
        flyRot = defaultRot;
    }


    void Update()
    {
        GetFrameCount();

        if (!flying)
            return;

        if (!camLocked)
        {
            Vector3 euler = flyRot.eulerAngles;
     
            euler.x -= Input.GetAxis("Mouse Y") * camSens;          
            euler.y += Input.GetAxis("Mouse X") * camSens;   

            flyRot = Quaternion.Euler(euler);
        }

        Vector3 p = GetBaseInput() * mainSpeed;

        if (Input.GetKey(KeyCode.LeftShift))
            p *= shiftSpeed;
       
        p *= Time.deltaTime;
            
        flyPos += flyRot * p;

        var main = Camera.main.transform;
        main.position = flyPos;
        main.rotation = flyRot;

        static Vector3 GetBaseInput() 
        {
            Vector3 velocity = new Vector3();

            if (Input.GetKey (KeyCode.W))
                velocity += new Vector3(0, 0 , 1);
            else if (Input.GetKey (KeyCode.S))
                velocity += new Vector3(0, 0, -1);

            if (Input.GetKey (KeyCode.A))
                velocity += new Vector3(-1, 0, 0);
            else if (Input.GetKey (KeyCode.D))
                velocity += new Vector3(1, 0, 0);

            if (Input.GetKey (KeyCode.Q))
                velocity += new Vector3(0, -1, 0);
            else if (Input.GetKey (KeyCode.E))
                velocity += new Vector3(0, 1, 0);

            return velocity;
        }
    }


    void OnGUI()
    {
        editorRect = GUILayout.Window(0, editorRect, DrawResizableBox, "Volume GUI Editor");

        if (!flying)
            return;

        Event ev = Event.current;

        if (!editorRect.Contains(ev.mousePosition))
        {
            if (ev.type == EventType.MouseDown && ev.button == 0)
            {
                ev.Use();
                Cursor.lockState = CursorLockMode.Locked;
                camLocked = false;
            }
            else if (ev.type == EventType.KeyDown && ev.keyCode == KeyCode.Escape)
            {
                ev.Use();
                Cursor.lockState = CursorLockMode.None;
                camLocked = true;
            }
        }
    }


    void DrawResizableBox(int windowID)
    {
        GUILayout.BeginHorizontal();

        GUIStyle buttonNormal = GUI.skin.FindStyle("Button");
        GUIStyle buttonPressed = new GUIStyle(buttonNormal);
        buttonPressed.normal = buttonPressed.onActive;
        buttonPressed.active = buttonPressed.onActive;
        buttonPressed.hover = buttonPressed.onActive;
        buttonPressed.focused = buttonPressed.onActive;

        for (int i = 0; i < tabNames.Length; i++)
        {
            if (GUILayout.Button(tabNames[i], tabNames[i] == selectedTab ? buttonPressed : buttonNormal))
                selectedTab = tabNames[i];
        }

        GUILayout.EndHorizontal();

        switch (selectedTab)
        {
            case "Volume":
                DrawVolumeEditor();
            break;

            case "Rendering":
                DrawRenderingEditor();
            break;

            case "Scene":
                DrawSceneSelection();
            break;

            case "Camera":
                DrawCameraEditor();
            break;
        }

        GUI.DragWindow();
    }


    void DrawCameraEditor()
    {
        GUILayout.BeginHorizontal();

        var main = Camera.main.gameObject;

        string buttonText = flying ? "Reset" : "Free Fly";

        if (GUILayout.Button(buttonText))
        {
            flying = !flying;

            if (!flying)
            {
                flyPos = defaultPos;
                flyRot = defaultRot;
                main.transform.position = defaultPos;
                main.transform.rotation = defaultRot;
            }   
            else 
            {
                defaultPos = main.transform.position;
                defaultRot = main.transform.rotation;
                flyPos = defaultPos;
                flyRot = defaultRot;
            }
        }

        GUILayout.EndHorizontal();
            
        bool fs = false;

        mainSpeed = Slider(mainSpeed, 0, 50, new GUIContent("Move Speed"), ref fs);
        shiftSpeed = Slider(shiftSpeed, 0, 5, new GUIContent("Boost Speed"), ref fs);

        camSens = Slider(camSens, 0, 10, new GUIContent("Look Sensitivity"), ref fs);
    }


    void DrawVolumeEditor()
    {
        for (int i = 0; i < sceneVolumes.Count; i++)
        {
            GameObject fVolume = sceneVolumes[i].gameObject;

            GUILayout.BeginHorizontal();

            GUILayout.Label(fVolume.name, GUILayout.Width(160f));

            bool active = fVolume.activeSelf;

            active = GUILayout.Toggle(active, GUIContent.none);

            if (fVolume.activeSelf != active)
                fVolume.SetActive(active);
        
            GUILayout.EndHorizontal();
        }
    }


    void DrawRenderingEditor()
    {
        GUILayout.Label(new GUIContent($"Render time: {lastFps}FPS ({avgTime:0.0}ms)"));
    }


    void DrawSceneSelection()
    {
        for (int i = 0; i < sceneNames.Length; i++)
        {
            GUILayout.BeginHorizontal();

            GUI.enabled = true;
            GUILayout.Label(sceneNames[i]);

            GUI.enabled = i != selectedSceneIndex;

            if (GUILayout.Button(i == selectedSceneIndex ? "Loaded" : "Load", GUILayout.Width(75)))
            {
                selectedSceneIndex = i;
                SceneManager.LoadScene(i);
            }

            GUILayout.EndHorizontal();
        }

        GUI.enabled = true;
    }


    static float Slider(float value, float leftValue, float rightValue, GUIContent content, ref bool isDirty, params GUILayoutOption[] layoutOptions)
    {
        GUILayout.BeginHorizontal();

        GUILayout.Label(content, layoutOptions);

        float newValue = GUILayout.HorizontalSlider(value, leftValue, rightValue);

        GUILayout.EndHorizontal();

        isDirty = !isDirty && newValue != value;
    
        return newValue;
    }
}
