import React, { useEffect, useMemo, useRef, useState } from "react";

const modes = [
  { id: "explain", label: "Explain Module", emoji: "📘" },
  { id: "bugs", label: "Bug Detection", emoji: "🐞" },
  { id: "fsm", label: "FSM Detection", emoji: "🔄" },
  { id: "docs", label: "Generate Documentation", emoji: "📝" },
  { id: "tb", label: "Generate Testbench", emoji: "🧪" },
  { id: "rag", label: "RAG Search", emoji: "🔎" },
];

const modeLabelToBackend = {
  explain: "Explain module",
  bugs: "Find bugs",
  fsm: "Detect FSM",
  docs: "Generate documentation",
  tb: "Generate testbench",
  rag: "General Q&A",
};

const pageStyle = {
  minHeight: "100vh",
  background: "linear-gradient(180deg, #f8fbff 0%, #eef5ff 100%)",
  color: "#0f172a",
  fontFamily: "Inter, Arial, sans-serif",
};

const cardStyle = {
  background: "#ffffff",
  borderRadius: "24px",
  boxShadow: "0 12px 36px rgba(15, 23, 42, 0.06)",
  border: "1px solid #e2e8f0",
};

const badgeStyle = {
  display: "inline-flex",
  alignItems: "center",
  gap: "6px",
  padding: "8px 12px",
  borderRadius: "999px",
  background: "#eff6ff",
  color: "#1d4ed8",
  fontSize: "13px",
  fontWeight: 600,
};

export default function App() {
  const [question, setQuestion] = useState(
    "Explain the FIFO module in this project and mention possible RTL issues."
  );
  const [mode, setMode] = useState("explain");
  const [model, setModel] = useState("llama3:latest");
  const [topK] = useState("2");
  const [files, setFiles] = useState([]);
  const [answer, setAnswer] = useState("");
  const [retrieved, setRetrieved] = useState([]);
  const [loading, setLoading] = useState(false);
  const [indexing, setIndexing] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [serverOk, setServerOk] = useState(false);
  const [error, setError] = useState("");
  const fileInputRef = useRef(null);

  const apiBase = useMemo(() => "http://127.0.0.1:8000", []);

  const refreshStatus = async () => {
    try {
      setError("");
      const res = await fetch(`${apiBase}/api/status`);
      if (!res.ok) throw new Error("Could not fetch backend status");
      const data = await res.json();
      setServerOk(true);
      setModel(data.model || "llama3:latest");
      setFiles(data.files || []);
    } catch (e) {
      setServerOk(false);
      setError("Backend not reachable. Make sure FastAPI is running on port 8000.");
    }
  };

  useEffect(() => {
    refreshStatus();
  }, []);

  const handleFileUpload = async (event) => {
    const selectedFiles = Array.from(event.target.files || []);
    if (!selectedFiles.length) return;

    const formData = new FormData();
    selectedFiles.forEach((file) => formData.append("files", file));

    try {
      setUploading(true);
      setError("");
      const res = await fetch(`${apiBase}/api/upload`, {
        method: "POST",
        body: formData,
      });
      if (!res.ok) throw new Error("Upload failed");
      await refreshStatus();
    } catch (e) {
      setError("File upload failed.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  };

  const buildIndex = async () => {
    try {
      setIndexing(true);
      setError("");
      const res = await fetch(`${apiBase}/api/rebuild-index`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
      if (!res.ok) throw new Error("Index build failed");
      await refreshStatus();
    } catch (e) {
      setError("Index build failed.");
    } finally {
      setIndexing(false);
    }
  };

  const runAssistant = async () => {
    if (!question.trim()) {
      setError("Enter a question first.");
      return;
    }

    try {
      setLoading(true);
      setError("");
      setAnswer("");
      setRetrieved([]);

      const res = await fetch(`${apiBase}/api/query`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          question,
          mode: modeLabelToBackend[mode],
          model,
          top_k: Number(topK),
        }),
      });

      if (!res.ok) throw new Error("Assistant query failed");
      const data = await res.json();
      setAnswer(data.answer || "No response returned.");
      setRetrieved(data.retrieved || []);
    } catch (e) {
      setError("Assistant request failed. If it is slow, try a shorter query.");
    } finally {
      setLoading(false);
    }
  };

  const activeMode = modes.find((m) => m.id === mode);

  return (
    <div style={pageStyle}>
      <div style={{ maxWidth: "1440px", margin: "0 auto", padding: "28px" }}>
        <div
          style={{
            ...cardStyle,
            padding: "34px 38px",
            marginBottom: "26px",
            background: "linear-gradient(135deg, #ffffff 0%, #f7fbff 55%, #edf5ff 100%)",
          }}
        >
          <div style={{ display: "flex", justifyContent: "space-between", gap: "18px", flexWrap: "wrap", alignItems: "center" }}>
            <div>
              <div style={{ ...badgeStyle, marginBottom: "12px" }}>✨ AI Assistant Platform</div>
              <h1
                style={{
                  margin: 0,
                  fontSize: "64px",
                  lineHeight: 0.95,
                  color: "#1d4ed8",
                  fontWeight: 800,
                  letterSpacing: "-0.03em",
                }}
              >
                NOUS
              </h1>
              <p
                style={{
                  marginTop: "14px",
                  marginBottom: 0,
                  color: "#475569",
                  fontSize: "19px",
                  maxWidth: "860px",
                  lineHeight: 1.7,
                }}
              >
                A clean and readable assistant for retrieval-augmented answers, technical help,
                and interactive AI workflows.
              </p>
            </div>
          </div>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "320px 1fr",
            gap: "28px",
            alignItems: "start",
          }}
        >
          <div
            style={{
              ...cardStyle,
              padding: "22px",
              position: "sticky",
              top: "18px",
              background: "linear-gradient(180deg, #ffffff 0%, #fbfdff 100%)",
            }}
          >
            <h2 style={{ marginTop: 0, marginBottom: "18px", fontSize: "24px" }}>Workspace</h2>

            <div
              style={{
                marginBottom: "16px",
                padding: "16px",
                borderRadius: "18px",
                background: serverOk ? "#ecfdf5" : "#fef2f2",
                border: `1px solid ${serverOk ? "#bbf7d0" : "#fecaca"}`,
              }}
            >
              <div style={{ fontWeight: 700, marginBottom: "6px", fontSize: "18px" }}>
                Backend Status
              </div>
              <div style={{ color: serverOk ? "#166534" : "#991b1b", fontSize: "15px" }}>
                {serverOk ? "Connected and ready" : "Backend not reachable"}
              </div>
            </div>

            <input
              ref={fileInputRef}
              type="file"
              multiple
              accept=".v,.sv,.vh,.txt"
              style={{ display: "none" }}
              onChange={handleFileUpload}
            />

            <button
              onClick={() => fileInputRef.current?.click()}
              style={{
                width: "100%",
                padding: "15px",
                marginBottom: "12px",
                background: "#2563eb",
                color: "white",
                border: "none",
                borderRadius: "16px",
                fontSize: "16px",
                fontWeight: 700,
                cursor: "pointer",
                boxShadow: "0 10px 20px rgba(37, 99, 235, 0.18)",
              }}
            >
              {uploading ? "Uploading..." : "Upload Dataset Files"}
            </button>

            <button
              onClick={buildIndex}
              style={{
                width: "100%",
                padding: "15px",
                background: "#ffffff",
                color: "#0f172a",
                border: "1px solid #cbd5e1",
                borderRadius: "16px",
                fontSize: "16px",
                fontWeight: 700,
                cursor: "pointer",
              }}
            >
              {indexing ? "Building..." : "Build / Rebuild Index"}
            </button>
          </div>

          <div style={{ display: "grid", gap: "24px" }}>
            <div
              style={{
                ...cardStyle,
                padding: "28px",
                background: "linear-gradient(180deg, #ffffff 0%, #fcfdff 100%)",
              }}
            >
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  gap: "16px",
                  flexWrap: "wrap",
                  marginBottom: "18px",
                }}
              >
                <div>
                  <h2 style={{ margin: 0, fontSize: "28px" }}>Ask NOUS</h2>
                  <p style={{ margin: "8px 0 0 0", color: "#64748b", fontSize: "15px" }}>
                    Ask your question and choose the type of assistant behavior.
                  </p>
                </div>
                <div style={badgeStyle}>
                  {activeMode?.emoji} {activeMode?.label}
                </div>
              </div>

              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(auto-fit, minmax(165px, 1fr))",
                  gap: "12px",
                  marginBottom: "18px",
                }}
              >
                {modes.map((m) => (
                  <button
                    key={m.id}
                    onClick={() => setMode(m.id)}
                    style={{
                      padding: "16px 14px",
                      borderRadius: "18px",
                      border: mode === m.id ? "1px solid #93c5fd" : "1px solid #e2e8f0",
                      background:
                        mode === m.id
                          ? "linear-gradient(180deg, #eff6ff 0%, #f8fbff 100%)"
                          : "#fff",
                      color: "#0f172a",
                      cursor: "pointer",
                      fontWeight: 700,
                      textAlign: "left",
                    }}
                  >
                    <div style={{ fontSize: "18px", marginBottom: "6px" }}>{m.emoji}</div>
                    <div style={{ fontSize: "14px" }}>{m.label}</div>
                  </button>
                ))}
              </div>

              <textarea
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                rows={7}
                style={{
                  width: "100%",
                  padding: "18px",
                  borderRadius: "20px",
                  border: "1px solid #cbd5e1",
                  fontSize: "16px",
                  lineHeight: 1.7,
                  resize: "vertical",
                  boxSizing: "border-box",
                  background: "#ffffff",
                  boxShadow: "inset 0 1px 2px rgba(15,23,42,0.03)",
                }}
              />

              {error && (
                <div
                  style={{
                    marginTop: "14px",
                    padding: "14px",
                    borderRadius: "14px",
                    background: "#fef2f2",
                    color: "#991b1b",
                    border: "1px solid #fecaca",
                  }}
                >
                  {error}
                </div>
              )}

              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  gap: "12px",
                  flexWrap: "wrap",
                  marginTop: "16px",
                }}
              >
                <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                  <span style={badgeStyle}>Local LLM</span>
                  <span style={badgeStyle}>RAG Enabled</span>
                </div>
                <button
                  onClick={runAssistant}
                  style={{
                    padding: "14px 24px",
                    background: "#0f172a",
                    color: "white",
                    border: "none",
                    borderRadius: "14px",
                    fontSize: "16px",
                    fontWeight: 700,
                    cursor: "pointer",
                  }}
                >
                  {loading ? "Running..." : "Run NOUS"}
                </button>
              </div>
            </div>

            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1.45fr 0.75fr",
                gap: "28px",
              }}
            >
              <div
                style={{
                  ...cardStyle,
                  padding: "28px",
                  background: "linear-gradient(180deg, #ffffff 0%, #fcfdff 100%)",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    marginBottom: "14px",
                  }}
                >
                  <h2 style={{ margin: 0, fontSize: "26px" }}>Assistant Output</h2>
                  <span style={badgeStyle}>{activeMode?.label}</span>
                </div>

                <div
                  style={{
                    marginTop: "12px",
                    whiteSpace: "pre-wrap",
                    background: "linear-gradient(180deg, #fbfdff 0%, #f8fafc 100%)",
                    padding: "22px",
                    borderRadius: "20px",
                    minHeight: "380px",
                    fontSize: "16px",
                    lineHeight: 1.8,
                    border: "1px solid #e2e8f0",
                  }}
                >
                  {answer || "Run NOUS to generate analysis and assistant output."}
                </div>
              </div>

              <div style={{ display: "grid", gap: "24px" }}>
                <div
                  style={{
                    ...cardStyle,
                    padding: "24px",
                    background: "linear-gradient(180deg, #ffffff 0%, #fcfdff 100%)",
                  }}
                >
                  <h2 style={{ marginTop: 0, fontSize: "24px" }}>Retrieved Files</h2>
                  <div
                    style={{
                      marginTop: "12px",
                      display: "grid",
                      gap: "10px",
                      maxHeight: "400px",
                      overflow: "auto",
                    }}
                  >
                    {(retrieved.length
                      ? retrieved
                      : files.slice(0, 8).map((file) => ({ file_name: file }))
                    ).map((item, idx) => (
                      <div
                        key={`${item.file_name}-${idx}`}
                        style={{
                          background: "#f8fafc",
                          padding: "14px",
                          borderRadius: "14px",
                          border: "1px solid #e2e8f0",
                        }}
                      >
                        <div style={{ fontWeight: 700, fontSize: "15px", marginBottom: "4px" }}>
                          {item.file_name}
                        </div>
                        {item.module_name ? (
                          <div style={{ fontSize: "13px", color: "#64748b" }}>
                            Module: {item.module_name}
                          </div>
                        ) : null}
                      </div>
                    ))}
                  </div>
                </div>

                <div
                  style={{
                    ...cardStyle,
                    padding: "24px",
                    background: "linear-gradient(180deg, #ffffff 0%, #fcfdff 100%)",
                  }}
                >
                  <h2 style={{ marginTop: 0, fontSize: "24px" }}>Quick Tips</h2>
                  <div style={{ display: "grid", gap: "10px", fontSize: "14px", lineHeight: 1.6, color: "#475569" }}>
                    <div
                      style={{
                        padding: "12px",
                        borderRadius: "14px",
                        background: "#f8fafc",
                        border: "1px solid #e2e8f0",
                      }}
                    >
                      Upload your files, rebuild the index, then ask your question.
                    </div>
                    <div
                      style={{
                        padding: "12px",
                        borderRadius: "14px",
                        background: "#f8fafc",
                        border: "1px solid #e2e8f0",
                      }}
                    >
                      Use Explain Module or Bug Detection for technical analysis.
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}