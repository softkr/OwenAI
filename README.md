# ai-server

Apple Silicon Mac에서 Qwen3.8-27B(MLX 4bit)를 로컬로 돌리는 서버와 웹 채팅 페이지입니다.

- **모델 서버** (8080): OpenAI 형식과 Anthropic 형식 API를 둘 다 지원하고, 이미지 입력도 받습니다.
- **웹 채팅 페이지** (8081): 브라우저용 채팅 화면입니다. 모델이 웹 검색과 페이지 읽기 도구를 쓸 수 있습니다.

## 실행

```sh
./run.sh                 # 모델 서버 + 웹 페이지 실행, 브라우저 자동으로 열림 (Ctrl+C로 둘 다 종료)
./run.sh server          # 모델 서버만 실행 (API용)
./run.sh server -- --max-tokens 8192   # -- 뒤 인자는 mlx_vlm.server로 그대로 전달
./serve.sh               # 모델 서버만 실행 (run.sh server와 같음)
./chat.sh                # 터미널 대화 (mlx_lm.chat)
```

처음 실행하면 모델을 `hf-cache/`에 내려받습니다. 이후에는 로딩만 합니다.

### 다른 기기에서 접속 (사설 IP)

두 서버는 `0.0.0.0`에서 열리므로, 같은 네트워크(공유기)에 있는 폰이나 다른 PC에서 `http://<이 Mac의 사설 IP>:8081`로 접속할 수 있습니다. `./run.sh`는 준비가 끝나면 이 주소를 같이 출력합니다.

- localhost와 사설 IP 대역(`192.168.x.x`, `10.x.x.x`, `172.16–31.x.x`)에서 온 요청만 받고, 공인 IP에서 온 요청은 거부합니다(API는 403).
- 이 Mac에서만 쓰려면 `BIND_HOST=127.0.0.1 ./run.sh`로 실행하세요.
- macOS 방화벽이 켜져 있으면 처음 실행할 때 Python의 수신 연결을 허용할지 물어봅니다. 허용해야 다른 기기에서 접속됩니다.

### 환경 변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `MODEL` | `mlx-community/Qwen3.8-27B-4bit` | 사용할 모델 |
| `DRAFT` | `mlx-community/Qwen3.8-27B-MTP-4bit` | MTP 추측 디코딩용 드래프트 모델 (약 1.9배 빠름). `DRAFT=`로 끄기 |
| `BIND_HOST` | `0.0.0.0` | 두 서버가 바인딩할 주소 (zsh가 `HOST`를 컴퓨터 이름으로 쓰기 때문에 이 이름 사용). `127.0.0.1`이면 이 Mac에서만 접속 |
| `PORT` | `8080` | 모델 서버 포트 |
| `WEB_PORT` | `8081` | 웹 페이지 포트 |
| `API_KEY` | (없음) | 서버 모드에서 요구할 API 키. 웹 모드는 실행할 때마다 새 키를 자동 생성 |
| `APC_ENABLED` | `1` | 자동 프리픽스 캐시: 이어지는 대화에서는 새 토큰만 prefill |
| `APC_DISK_ENABLED` | `0` | 프리픽스 캐시 디스크 저장 (기본은 메모리만) |

## API

서버는 localhost와 사설 IP에서 온 요청만 받습니다. 같은 네트워크의 다른 기기에서는 `127.0.0.1` 대신 이 Mac의 사설 IP를 쓰면 됩니다. 외부 클라이언트에서 쓸 때는 키를 직접 정해서 띄우세요(키 없이 띄우면 같은 네트워크의 누구나 쓸 수 있습니다).

```sh
API_KEY=mykey ./run.sh server
```

| 형식 | 엔드포인트 | 인증 헤더 |
|---|---|---|
| OpenAI | `POST /v1/chat/completions`, `POST /v1/responses` | `Authorization: Bearer <key>` |
| Anthropic | `POST /v1/messages`, `POST /v1/messages/count_tokens` | `x-api-key: <key>` (Bearer도 됨) |
| 공통 | `GET /v1/models`, `GET /health` | 위 둘 중 아무거나 |

스트리밍(`"stream": true`)은 두 형식 모두 지원합니다.

### OpenAI 형식

```python
from openai import OpenAI

client = OpenAI(base_url="http://127.0.0.1:8080/v1", api_key="mykey")
r = client.chat.completions.create(
    model="mlx-community/Qwen3.8-27B-4bit",
    messages=[{"role": "user", "content": "안녕"}],
)
print(r.choices[0].message.content)
```

```sh
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Authorization: Bearer mykey" -H "content-type: application/json" \
  -d '{"model":"mlx-community/Qwen3.8-27B-4bit","messages":[{"role":"user","content":"안녕"}]}'
```

### Anthropic 형식

```python
import anthropic

client = anthropic.Anthropic(base_url="http://127.0.0.1:8080", api_key="mykey")
r = client.messages.create(
    model="mlx-community/Qwen3.8-27B-4bit",
    max_tokens=1024,
    messages=[{"role": "user", "content": "안녕"}],
)
print(r.content[0].text)
```

```sh
curl http://127.0.0.1:8080/v1/messages \
  -H "x-api-key: mykey" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d '{"model":"mlx-community/Qwen3.8-27B-4bit","max_tokens":1024,"messages":[{"role":"user","content":"안녕"}]}'
```

> `base_url` 주의: OpenAI SDK는 `/v1`까지 넣고, Anthropic SDK는 `/v1` 없이 넣습니다.

## 웹 채팅 페이지

`./run.sh`로 띄우면 `http://127.0.0.1:8081`이 열립니다.

- 이미지 첨부
- 생각 모드(thinking) 켜기/끄기
- 모델이 호출하는 도구: `web_search`(웹 검색, 상위 결과 페이지에서 관련 문단 추출), `fetch_url`(특정 페이지 본문 읽기)

웹 모드는 실행할 때마다 새 API 키를 만들고 `web/config.js`로 페이지에 넘깁니다. 모델 서버는 모든 CORS origin을 허용하므로, 이 키가 있어야 다른 웹사이트가 서버를 쓰지 못합니다. 종료하면 `config.js`는 지워집니다.

## 파일 구성

| 파일 | 내용 |
|---|---|
| `run.sh` | 모델 서버 + 웹 페이지 통합 실행 스크립트 |
| `serve.sh` | 모델 서버만 실행 |
| `web.sh` | 이전 방식의 통합 실행 스크립트 (`serve.sh` + 웹 서버) |
| `chat.sh` | 터미널 대화 |
| `api_server.py` | `mlx_vlm.server` 래퍼. Anthropic SDK의 `x-api-key` 헤더를 Bearer 인증으로 바꿔 넘기고, 사설망 밖의 요청을 거부 |
| `web/server.py` | 정적 파일 서버 + `/api/search`, `/api/fetch` (웹 도구). 사설망 클라이언트만 받음. 웹 도구는 로컬/내부망 주소를 읽지 못하게 막음 |
| `web/index.html` | 채팅 페이지 (`index.classic.html`은 이전 버전) |
| `hf-cache/` | Hugging Face 모델 캐시 (`HF_HOME`) |
| `.venv/` | Python 가상환경 (mlx, mlx_vlm, mlx_lm, trafilatura, ddgs 등) |
