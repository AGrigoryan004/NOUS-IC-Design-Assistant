import os
import re
import json
import pickle
from pathlib import Path
from typing import List, Dict, Tuple

import requests
import numpy as np
import streamlit as st

try:
    import faiss
except ImportError:
    faiss = None

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    SentenceTransformer = None


# =========================
# Configuration
# =========================
DATA_DIR = Path("./dataset")
INDEX_DIR = Path("./index_store")
INDEX_DIR.mkdir(exist_ok=True)

FAISS_PATH = INDEX_DIR / "verilog_index.faiss"
META_PATH = INDEX_DIR / "metadata.pkl"

OLLAMA_URL = "http://localhost:11434/api/chat"
DEFAULT_MODEL = "llama3:latest"
EMBED_MODEL = "all-MiniLM-L6-v2"
CHUNK_SIZE = 1200
CHUNK_OVERLAP = 200
TOP_K = 4


# =========================
# Helpers
# =========================
def find_design_files(root: Path) -> List[Path]:
    exts = {".v", ".sv", ".vh", ".txt"}
    files = []
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in exts:
            files.append(path)
    return sorted(files)


def classify_file(file_path: Path) -> str:
    name = file_path.name.lower()
    if "tb" in name or "testbench" in name:
        return "testbench"
    return "verilog"


def extract_module_name(text: str, fallback: str) -> str:
    match = re.search(r"\bmodule\s+(\w+)", text)
    return match.group(1) if match else fallback


def read_text_file(file_path: Path) -> str:
    try:
        return file_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return file_path.read_text(encoding="latin-1", errors="ignore")


def chunk_text(text: str, chunk_size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> List[str]:
    if len(text) <= chunk_size:
        return [text]

    chunks = []
    start = 0
    while start < len(text):
        end = min(start + chunk_size, len(text))
        chunks.append(text[start:end])
        if end == len(text):
            break
        start = max(end - overlap, start + 1)
    return chunks


def build_documents(root: Path) -> List[Dict]:
    docs = []
    files = find_design_files(root)
    for file_path in files:
        raw = read_text_file(file_path)
        file_type = classify_file(file_path)
        module_name = extract_module_name(raw, file_path.stem)
        chunks = chunk_text(raw)

        for i, chunk in enumerate(chunks):
            docs.append(
                {
                    "file_path": str(file_path),
                    "file_name": file_path.name,
                    "file_type": file_type,
                    "module_name": module_name,
                    "chunk_id": i,
                    "text": chunk,
                }
            )
    return docs


@st.cache_resource(show_spinner=False)
def load_embedder():
    if SentenceTransformer is None:
        raise ImportError(
            "sentence-transformers is not installed. Install it with: pip install sentence-transformers"
        )
    return SentenceTransformer(EMBED_MODEL)


def embed_texts(texts: List[str]) -> np.ndarray:
    model = load_embedder()
    vectors = model.encode(texts, show_progress_bar=True, convert_to_numpy=True)
    vectors = np.asarray(vectors, dtype=np.float32)
    faiss.normalize_L2(vectors)
    return vectors


def save_index(index, metadata: List[Dict]):
    faiss.write_index(index, str(FAISS_PATH))
    with open(META_PATH, "wb") as f:
        pickle.dump(metadata, f)


def load_index() -> Tuple[object, List[Dict]]:
    if not FAISS_PATH.exists() or not META_PATH.exists():
        return None, []
    index = faiss.read_index(str(FAISS_PATH))
    with open(META_PATH, "rb") as f:
        metadata = pickle.load(f)
    return index, metadata


def build_faiss_index(root: Path) -> Tuple[object, List[Dict], int]:
    if faiss is None:
        raise ImportError("faiss is not installed. Install it with: pip install faiss-cpu")

    docs = build_documents(root)
    if not docs:
        raise ValueError(f"No design files found in {root.resolve()}")

    vectors = embed_texts([d["text"] for d in docs])
    dim = vectors.shape[1]
    index = faiss.IndexFlatIP(dim)
    index.add(vectors)
    save_index(index, docs)
    return index, docs, len(docs)


def search_index(query: str, index, metadata: List[Dict], top_k: int = TOP_K) -> List[Dict]:
    query_vec = embed_texts([query])
    scores, ids = index.search(query_vec, top_k)

    results = []
    for score, idx in zip(scores[0], ids[0]):
        if idx < 0 or idx >= len(metadata):
            continue
        item = metadata[idx].copy()
        item["score"] = float(score)
        results.append(item)
    return results


def format_context(results: List[Dict]) -> str:
    parts = []
    for i, item in enumerate(results, start=1):
        parts.append(
            f"[Context {i}]\n"
            f"File: {item['file_name']}\n"
            f"Type: {item['file_type']}\n"
            f"Module: {item['module_name']}\n"
            f"Chunk ID: {item['chunk_id']}\n"
            f"Content:\n{item['text']}\n"
        )
    return "\n\n".join(parts)


def build_system_prompt() -> str:
    return (
        "You are an assistant for integrated circuit design and Verilog development. "
        "You help explain Verilog modules, analyze testbenches, detect common RTL mistakes, "
        "suggest fixes, and draft new testbenches. "
        "Only rely on the provided context when referencing the user's project files. "
        "If context is insufficient, say what is missing. "
        "Answer in a structured and technically accurate way."
    )


def build_user_prompt(user_query: str, context: str, mode: str) -> str:
    task_guidance = {
        "Explain module": "Explain the module purpose, ports, internal logic, and expected behavior.",
        "Find bugs": "Analyze the code and identify likely bugs, synthesis issues, or simulation issues.",
        "Generate testbench": "Generate a useful Verilog testbench for the relevant module.",
        "Improve code": "Suggest an improved version or refactoring strategy.",
        "General Q&A": "Answer the question using the context.",
    }

    return (
        f"Task: {mode}\n"
        f"Instruction: {task_guidance.get(mode, 'Answer the question using the context.')}\n\n"
        f"User question:\n{user_query}\n\n"
        f"Project context:\n{context}\n\n"
        "When relevant, cite the file names you used."
    )


def call_ollama(model: str, system_prompt: str, user_prompt: str) -> str:
    payload = {
        "model": model,
        "stream": False,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "options": {
            "temperature": 0.2,
        },
    }

    response = requests.post(OLLAMA_URL, json=payload, timeout=180)
    response.raise_for_status()
    data = response.json()

    if "message" in data and "content" in data["message"]:
        return data["message"]["content"]

    raise RuntimeError(f"Unexpected Ollama response: {json.dumps(data, indent=2)}")


def get_project_stats(root: Path) -> Dict[str, int]:
    files = find_design_files(root)
    verilog_count = 0
    tb_count = 0

    for f in files:
        if classify_file(f) == "testbench":
            tb_count += 1
        else:
            verilog_count += 1

    return {
        "all_files": len(files),
        "verilog_files": verilog_count,
        "testbench_files": tb_count,
    }


# =========================
# UI
# =========================
st.set_page_config(page_title="IC Design Assistant", layout="wide")
st.title("IC Design Assistant with Local Llama + RAG")
st.caption("Verilog/Testbench օգնական տեղային LLM-ով")

with st.sidebar:
    st.header("Settings")
    model_name = st.text_input("Ollama model", value=DEFAULT_MODEL)
    data_dir_input = st.text_input("Dataset folder", value=str(DATA_DIR))
    top_k = st.slider("Top-K retrieved chunks", min_value=1, max_value=8, value=TOP_K)
    mode = st.selectbox(
        "Assistant mode",
        ["General Q&A", "Explain module", "Find bugs", "Generate testbench", "Improve code"],
    )

    data_root = Path(data_dir_input)
    stats = get_project_stats(data_root) if data_root.exists() else None

    if stats:
        st.subheader("Dataset stats")
        st.write(f"All files: {stats['all_files']}")
        st.write(f"Verilog files: {stats['verilog_files']}")
        st.write(f"Testbench files: {stats['testbench_files']}")

    if st.button("Build / Rebuild Index"):
        try:
            with st.spinner("Building vector index..."):
                _, _, total_chunks = build_faiss_index(data_root)
            st.success(f"Index built successfully. Total chunks: {total_chunks}")
        except Exception as e:
            st.error(f"Index build failed: {e}")

st.subheader("Ask your assistant")
user_query = st.text_area(
    "Enter your question",
    placeholder="Example: Explain the counter module and tell me if the reset logic is correct.",
    height=120,
)

col1, col2 = st.columns([1, 1])
with col1:
    ask_btn = st.button("Run Assistant")
with col2:
    show_context = st.checkbox("Show retrieved context", value=True)

if ask_btn:
    try:
        if faiss is None:
            st.error("FAISS is missing. Install it with: pip install faiss-cpu")
        elif SentenceTransformer is None:
            st.error("sentence-transformers is missing. Install it with: pip install sentence-transformers")
        elif not user_query.strip():
            st.warning("Please enter a question.")
        else:
            index, metadata = load_index()
            if index is None or not metadata:
                st.warning("Index not found. Build the index first from the sidebar.")
            else:
                with st.spinner("Searching project files..."):
                    results = search_index(user_query, index, metadata, top_k=top_k)
                    context = format_context(results)

                with st.spinner("Querying local Llama model..."):
                    answer = call_ollama(
                        model=model_name,
                        system_prompt=build_system_prompt(),
                        user_prompt=build_user_prompt(user_query, context, mode),
                    )

                st.subheader("Assistant response")
                st.write(answer)

                if show_context:
                    st.subheader("Retrieved context")
                    for item in results:
                        with st.expander(
                            f"{item['file_name']} | {item['module_name']} | score={item['score']:.3f}"
                        ):
                            st.code(item["text"], language="verilog")
                            st.caption(f"Path: {item['file_path']}")
                            st.caption(f"Type: {item['file_type']}, Chunk ID: {item['chunk_id']}")
    except requests.exceptions.ConnectionError:
        st.error(
            "Could not connect to Ollama. Make sure Ollama is running locally and the model is installed."
        )
    except Exception as e:
        st.error(f"Error: {e}")

st.divider()
st.subheader("Recommended folder structure")
st.code(
    """
project/
├── ic_design_assistant_app.py
├── dataset/
│   ├── alu.v
│   ├── alu_tb.v
│   ├── counter.v
│   ├── counter_tb.v
│   └── ...
└── index_store/
""",
    language="text",
)

st.subheader("Install requirements")
st.code(
    "pip install streamlit requests sentence-transformers faiss-cpu numpy",
    language="bash",
)

st.subheader("Run")
st.code("streamlit run ic_design_assistant_app.py", language="bash")