# Antes

Antes is an iOS prototype for turning screen-time blocks into positive rituals.

The app lets a user describe a habit, then generates a short ritual interface before distracting apps unlock. Examples include prayer/scripture, gratitude journaling, push-ups, hydration, meditation, and homework quizzes.

## What is included

- Native SwiftUI iOS app in `Antes/`
- Local OpenAI-backed backend in `Backend/server.mjs`
- Browser preview in `Preview/`
- Generated visual asset for the push-up ritual

## Run the AI backend

Create `.env.local` from `.env.example` and set `OPENAI_API_KEY`.

```bash
PORT=8790 node Backend/server.mjs
```

Health check:

```bash
curl http://127.0.0.1:8790/health
```

## Run the browser preview

Serve the project root locally, then open:

```text
http://127.0.0.1:8791/Preview/index.html
```

The preview calls:

```text
http://127.0.0.1:8790/api/generate-ritual
```

## Run the iOS app

Open `Antes.xcodeproj` in Xcode, run the `Antes` scheme on an iOS Simulator, and keep the local backend running on port `8790`.

The API key stays on the backend. Do not embed it in the iOS app.
