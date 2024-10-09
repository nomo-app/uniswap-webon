{{flutter_js}}
{{flutter_build_config}}

// Create the loading element
const loadingDiv = document.createElement("div");
loadingDiv.className = "loading";
loadingDiv.id = "loading-overlay";
const loaderDiv = document.createElement("div");
loaderDiv.className = "loader";
const img = document.createElement("img");
img.src = "logo.png"; // Replace with your actual image URL
img.alt = "Loading";
loaderDiv.appendChild(img);
loadingDiv.appendChild(loaderDiv);
document.body.appendChild(loadingDiv);

function hideLoading() {
    const loadingOverlay = document.getElementById('loading-overlay');
    loadingOverlay.style.opacity = '0';
    setTimeout(() => {
        if (document.body.contains(loadingOverlay)) {
            document.body.removeChild(loadingOverlay);
        }
    }, 200); // Wait for fade out to complete
}

// Customize the app initialization process
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();

    // Fade out and remove the loading spinner when the app runner is ready
    hideLoading();
    await appRunner.runApp();
  },
});