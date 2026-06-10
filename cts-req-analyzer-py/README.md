# CTS Requirement Analyzer (Python)

Hệ thống phân tích yêu cầu sử dụng RAG (Retrieval-Augmented Generation) để đánh giá tính khả thi và tác động của yêu cầu mới dựa trên tài liệu kỹ thuật PlantUML hiện có.

## Cài Đặt

### 1. Tạo Virtual Environment

```bash
# Windows
python -m venv venv
venv\Scripts\activate

# Linux/Mac
python3 -m venv venv
source venv/bin/activate
```

### 2. Cài Đặt Dependencies

```bash
pip install -r requirements.txt
```

### 3. Cấu Hình Environment

Tạo file `.env` từ template:

```bash
copy .env.example .env
```

Sau đó mở `.env` và điền OpenAI API key của bạn:

```
OPENAI_API_KEY=sk-your-api-key-here
```

## Sử Dụng

### Chạy Chương Trình

```bash
python main.py
```

### Các Lệnh

Khi chương trình chạy, bạn có thể:

1. **Phân tích yêu cầu**: Gõ yêu cầu của bạn
   ```
   > Thêm tính năng Corner Kick vào MatchMonitor
   ```

2. **Tìm kiếm tài liệu**: Dùng lệnh `search`
   ```
   > search MatchMonitor
   ```

3. **Rebuild index**: Dùng lệnh `reindex`
   ```
   > reindex
   ```

4. **Thoát**: Gõ `quit` hoặc nhấn Ctrl+C

## Cấu Trúc Project

```
cts-req-analyzer-py/
├── core/
│   ├── parser.py      # Parse file .puml
│   ├── indexer.py     # Quản lý Vector Database
│   └── retriever.py   # RAG Engine
├── models/
│   └── schema.py      # Data models
├── data/              # Vector DB storage (auto-created)
├── main.py            # Entry point
├── requirements.txt   # Dependencies
├── .env.example       # Environment template
└── README.md
```

## Ví Dụ Sử Dụng

```python
from core.parser import PumlParser
from core.indexer import KnowledgeBase
from core.retriever import RAGEngine

# Initialize
parser = PumlParser()
kb = KnowledgeBase()
engine = RAGEngine(kb)

# Index documents
chunks = parser.parse_directory('../md')
kb.ingest(chunks)

# Analyze requirement
result = engine.analyze("Thêm tính năng thanh toán mới")
print(result.analysis)
```

## Lưu Ý

- Lần chạy đầu tiên sẽ mất thời gian để index tất cả file .puml
- Vector database được lưu trong thư mục `data/` và sẽ được tái sử dụng cho các lần chạy sau
- Sử dụng lệnh `reindex` nếu bạn thêm/sửa file .puml mới
