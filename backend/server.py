from pathlib import Path
from typing import List, Dict, Tuple
import pickle
import re

import numpy as np
import requests
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware

try:
    import faiss
except ImportError:
    faiss = None

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    SentenceTransformer = None


BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "dataset"
INDEX_DIR = BASE_DIR / "index_store"
INDEX_DIR.mkdir(exist_ok=True)

FAISS_PATH = INDEX_DIR / "verilog_index.faiss"
META_PATH = INDEX_DIR / "metadata.pkl"

OLLAMA_URL = "http://localhost:11434/api/chat"
DEFAULT_MODEL = "llama3:latest"
EMBED_MODEL = "all-MiniLM-L6-v2"
CHUNK_SIZE = 700
CHUNK_OVERLAP = 150

app = FastAPI(title="NOUS Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def find_design_files(root: Path) -> List[Path]:
    exts = {".v", ".sv", ".vh", ".txt"}
    return sorted([p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in exts])


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
    for file_path in find_design_files(root):
        raw = read_text_file(file_path)
        file_type = classify_file(file_path)
        module_name = extract_module_name(raw, file_path.stem)

        for i, chunk in enumerate(chunk_text(raw)):
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


_model = None


def load_embedder():
    global _model
    if SentenceTransformer is None:
        raise ImportError("sentence-transformers is not installed")
    if _model is None:
        _model = SentenceTransformer(EMBED_MODEL)
    return _model


def embed_texts(texts: List[str]) -> np.ndarray:
    if faiss is None:
        raise ImportError("faiss-cpu is not installed")
    model = load_embedder()
    vectors = model.encode(texts, show_progress_bar=False, convert_to_numpy=True)
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


def build_faiss_index(root: Path):
    if faiss is None:
        raise ImportError("faiss-cpu is not installed")

    docs = build_documents(root)
    if not docs:
        raise ValueError("No design files found in dataset")

    vectors = embed_texts([d["text"] for d in docs])
    dim = vectors.shape[1]
    index = faiss.IndexFlatIP(dim)
    index.add(vectors)
    save_index(index, docs)
    return len(docs)


def search_index(query: str, top_k: int = 2) -> List[Dict]:
    index, metadata = load_index()
    if index is None or not metadata:
        return []

    query_vec = embed_texts([query])
    scores, ids = index.search(query_vec, top_k)

    results = []
    for score, idx in zip(scores[0], ids[0]):
        if 0 <= idx < len(metadata):
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


def build_system_prompt(mode: str) -> str:
    if mode == "Find bugs":
        return (
            "You are an expert RTL verification engineer. "
            "Analyze the given Verilog module and detect logical bugs, race conditions, "
            "blocking/non-blocking misuse, reset issues, latches, and synthesis problems. "
            "Be concrete and structured."
        )

    if mode == "Detect FSM":
        return (
            "You are an RTL design expert. "
            "Analyze the Verilog module and determine whether it implements a finite state machine. "
            "If yes, identify the states, transitions, state register logic, and output logic. "
            "If no, clearly say that no explicit FSM was detected."
        )

    if mode == "Generate documentation":
        return (
            "You are an IC design documentation assistant. "
            "Generate documentation for the Verilog module including purpose, inputs, outputs, "
            "parameters, internal architecture, timing behavior, reset behavior, and usage notes."
        )

    if mode == "Generate testbench":
        return (
            "You are an RTL verification assistant. "
            "Generate a useful Verilog testbench for the given module. "
            "Include clock/reset if needed, directed tests, and expected behavior comments."
        )

    if mode == "Explain module":
        return (
            "You are an assistant for integrated circuit design and Verilog development. "
            "Explain the module clearly: purpose, ports, main logic, sequential/combinational behavior, "
            "and expected operation."
        )

    return (
        "You are NOUS, an assistant for integrated circuit design and Verilog development. "
        "Use the provided project context to answer accurately and technically."
    )


def build_user_prompt(question: str, context: str, mode: str) -> str:
    return (
        f"Task: {mode}\n\n"
        f"User question:\n{question}\n\n"
        f"Project context:\n{context}\n\n"
        "Use the project context. Mention file names when relevant. "
        "Be structured, concise, and technically accurate."
    )


def call_ollama(model: str, system_prompt: str, user_prompt: str) -> str:
    payload = {
        "model": model,
        "stream": False,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "options": {"temperature": 0.0},
    }

    response = requests.post(OLLAMA_URL, json=payload, timeout=600)
    response.raise_for_status()
    data = response.json()
    return data["message"]["content"]


def get_stats() -> Dict[str, int]:
    files = find_design_files(DATA_DIR)
    verilog_files = sum(1 for f in files if classify_file(f) == "verilog")
    tb_files = sum(1 for f in files if classify_file(f) == "testbench")
    return {
        "all_files": len(files),
        "verilog_files": verilog_files,
        "testbench_files": tb_files,
    }


@app.get("/api/status")
def status():
    files = [p.name for p in find_design_files(DATA_DIR)]
    index, metadata = load_index()
    return {
        "ok": True,
        "model": DEFAULT_MODEL,
        "files": files,
        "stats": get_stats(),
        "indexed_chunks": len(metadata) if metadata else 0,
    }


@app.post("/api/upload")
async def upload_files(files: List[UploadFile] = File(...)):
    DATA_DIR.mkdir(exist_ok=True)
    saved = []
    for file in files:
        target = DATA_DIR / file.filename
        content = await file.read()
        target.write_bytes(content)
        saved.append(file.filename)
    return {"uploaded": saved}


@app.post("/api/rebuild-index")
async def rebuild_index(payload: Dict):
    total_chunks = build_faiss_index(DATA_DIR)
    return {"ok": True, "indexed_chunks": total_chunks}


@app.post("/api/query")
async def query(payload: Dict):
    question = payload.get("question", "")
    mode = payload.get("mode", "General Q&A")
    model = payload.get("model", DEFAULT_MODEL)
    top_k = int(payload.get("top_k", 2))

    results = search_index(question, top_k=top_k)
    context = format_context(results)

    system_prompt = build_system_prompt(mode)
    user_prompt = build_user_prompt(question, context, mode)

    answer = call_ollama(
        model=model,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
    )

    return {"answer": answer, "retrieved": results}