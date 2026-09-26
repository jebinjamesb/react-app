import React from "react";

function App() {
  return (
    <div style={{ padding: 20 }}>
      <h2>Environment Variables</h2>
      <p><strong>Title:</strong> {process.env.REACT_APP_TITLE}</p>
      <p><strong>Version:</strong> {process.env.REACT_APP_VERSION}</p>
    </div>
  );
}

export default App;
