# Mirror — AI Personal Stylist

A native iOS app that tells you whether an outfit suits you — and lets you try it on.

Upload a photo of yourself + a screenshot of any outfit from Pinterest or Instagram. Mirror uses Gemini 3.1 Flash-Lite to analyze color harmony and silhouette compatibility against your body type and style profile, then gives you a clear YES or NO verdict with reasoning. Tap "Try It On" to see yourself wearing the outfit via Perfect Corp's virtual try-on API.

## Features

- **Outfit Verdict** — AI analysis of any outfit against your personal style profile
- **Virtual Try-On** — Perfect Corp Clothes Try-On API renders you in the outfit
- **Style Chat** — Ask your AI stylist what to wear, get a lookbook preview + try-on
- **Style Profile** — Personalized onboarding (vibe, body type, gender, priority)

## Tech Stack

- Swift + SwiftUI
- Gemini 3.1 Flash-Lite (multimodal outfit verdict + streaming style chat)
- Perfect Corp YouCam API (virtual try-on + outfit preview)
- URLSession async/await — no backend

## Setup

1. Clone the repo
2. Copy `APIKeys.swift.example` → `APIKeys.swift`
3. Add your Gemini and Perfect Corp API keys
4. Build and run in Xcode 15+, iOS 17+

## Built for

DevNetwork AI + ML Hackathon 2026 — Perfect Corp Challenge
