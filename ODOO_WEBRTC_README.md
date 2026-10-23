# Odoo Discuss (Mail RTC) WebRTC Voice Call - Flutter Buddy

This document provides complete instructions for running, testing, and troubleshooting the Flutter "Buddy" audio voice calling integration with Odoo Discuss (`addons/mail`).

---

## 1. Architecture Overview

Audio communication goes **peer-to-peer** (WebRTC) between the Odoo Web Client (Admin on desktop browser) and the Flutter App (Buddy on mobile phone). Odoo acts as the **signaling server** and provides ICE servers.

```
┌───────────────────────────────────────┐
│     Odoo Desktop Web Client           │
│           (Admin)                     │
└──────────────────┬────────────────────┘
                   │  1. HTTP /mail/rtc/channel/join_call
                   │  2. WebSocket Bus (/websocket)
                   │  3. HTTP /mail/rtc/session/notify_call_members
                   ▼
┌───────────────────────────────────────┐
│         Odoo Backend (Ngrok)          │
│   (Signaling & Session Coordinator)   │
└──────────────────▲────────────────────┘
                   │  1. /web/session/authenticate (session_id cookie)
                   │  2. /mail/rtc/channel/join_call (iceServers, sessionId)
                   │  3. WebSocket Bus (/websocket: discuss.channel.rtc.session/*)
                   │  4. /mail/rtc/session/notify_call_members (offer/answer/candidates)
                   │
┌──────────────────┴────────────────────┐
│          Flutter Mobile App           │
│                (Buddy)                │
└───────────────────────────────────────┘
                   ▲
                   │
                   │ Peer-to-Peer RTP Audio (Direct UDP or STUN/TURN Relay)
                   ▼
┌───────────────────────────────────────┐
│        WebRTC Media Stream            │
└───────────────────────────────────────┘
```

### Key Modules:
- **`lib/config.dart`**: Central configuration (`baseUrl`, `db`, `login`, `password`, `defaultChannelId`, STUN fallback).
- **`lib/features/call/data/services/odoo_api.dart`**: Pure HTTP/JSON-RPC client handling authentication, cookie preservation, `join_call`, `leave_call`, `notify_call_members`, and `update_and_broadcast`.
- **`lib/features/call/data/services/signaling_service.dart`**: Connects to Odoo WebSocket bus (`/websocket`), listens for peer notifications and channel updates, and sends outgoing signaling messages.
- **`lib/features/call/data/services/rtc_call_service.dart`**: Manages `RTCPeerConnection`, unified-plan SDP exchange, candidate queueing, polite peer negotiation, media tracks, and 20s timeout diagnosis.
- **`lib/features/call/data/services/rtc_logger.dart`**: Timestamped in-memory logging (`~300` lines), candidate type parsing (`host`, `srflx`, `relay`), diagnosis rules, and `pc.getStats()` inspector.
- **`lib/features/call/presentation/pages/rtc_connection_screen.dart`**: UI portal for logging in, loading defaults, launching calls, and opening diagnostics.
- **`lib/features/call/presentation/pages/audio_call_screen.dart`**: In-call audio screen (mute, speaker toggle, hang up, call timer, connection badge).
- **`lib/features/call/presentation/pages/rtc_debug_log_screen.dart`**: Live diagnostics viewer with candidate summary, diagnosis box, filter tabs, and "Copy Logs" button.

---

## 2. Configuration (`lib/config.dart`)

Configure your parameters in `lib/config.dart`:

```dart
class CallConfig {
  /// Base HTTPS ngrok URL for Odoo (never localhost)
  static const String defaultBaseUrl = 'https://sanitizer-marsupial-delegator.ngrok-free.dev';

  /// Odoo Database Name
  static const String defaultDb = 'test18';

  /// Default Login Username / Email for Buddy
  static const String defaultLogin = 'buddy@example.com';

  /// Default Password
  static const String defaultPassword = 'admin';

  /// Default Odoo Discuss Channel ID
  static const int defaultChannelId = 1;

  /// Fallback STUN server when Odoo returns empty iceServers
  static const List<Map<String, dynamic>> stunFallback = [
    {'urls': ['stun:stun.l.google.com:19302']},
  ];

  /// Timeout in seconds before issuing an automatic ICE diagnosis
  static const int iceTimeoutSeconds = 20;
}
```

---

## 3. How to Run

1. **Verify dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run the Flutter app:**
   ```bash
   flutter run
   ```

3. **Navigate to the Odoo Voice Call Portal:**
   - Tap the phone icon with settings in the **Calls** tab (`/calls`), or navigate directly to `/rtc-connect`.
   - Tap **"Defaults"** to populate fields from `config.dart`.
   - Tap **"1. Login"** to authenticate session cookie against Odoo.
   - Tap **"2. Join Voice Call"** to initiate or join the audio call on the Discuss channel.

---

## 4. Cross-Network Testing Procedure

### Test Setup:
- **Admin Laptop**: Connected to **Home/Office WiFi**, opening Odoo in Chrome/Firefox via the ngrok URL (e.g. `https://xxx.ngrok-free.dev`).
- **Buddy Phone**: Connected to **Cellular Mobile Data (4G/5G)** with WiFi toggled OFF.
- Both ends communicate via the ngrok HTTPS domain.

### Step-by-Step Flow:
1. **Admin joins call from Browser**:
   - Admin logs into Odoo web client.
   - Opens Discuss channel (e.g., General or channel `#1`).
   - Clicks the **Phone icon** (Start audio call).
2. **Buddy joins call from Phone**:
   - In Flutter app, open **Odoo Voice Call** portal.
   - Ensure `Channel ID` matches the Discuss channel (e.g. `1`).
   - Tap **"2. Join Voice Call"**.
3. **Observation**:
   - WebRTC will perform ICE gathering, send offers/answers over Odoo's bus, exchange candidates, and transition state to `Connected`.
   - Audio flows between browser microphone/speakers and phone microphone/speaker.
4. **Diagnostics Verification**:
   - Tap the terminal icon in the top right at any time to open **RTC Live Diagnostics**.
   - Tap **"Copy all logs to clipboard"** to paste logs for analysis.

---

## 5. How to Read the DIAGNOSIS Logs

When gathering finishes or if a connection fails/times out after 20 seconds, the app prints a prominent diagnostic line:

```
================================================================================
>>> DIAGNOSIS: <Result> <<<
================================================================================
```

### Diagnosis Evaluation Rules:

| Log Signature / Candidate Counts | Diagnosis Result | Meaning & Solution |
| :--- | :--- | :--- |
| `ICE: connected` or `completed` (no relay candidates) | **"Connected without TURN"** | Direct P2P connection succeeded via host or STUN srflx. |
| `ICE: connected` with `relay > 0` | **"Connected via TURN (relay)"** | NAT traversal required relaying; Coturn/Twilio TURN succeeded. |
| `localHostCount=0, srflx=0, relay=0` | **"App code issue: no candidates generated"** | PeerConnection failed to initialize gathering or microphone permission denied. |
| `host > 0`, `srflx == 0`, `relay == 0` | **"STUN unreachable (firewall or wrong config)"** | Phone could not reach Google STUN port 19302 (UDP blocked on carrier or firewall). |
| `srflx > 0`, but ICE state becomes `failed` or 20s timeout | **"Signaling OK but direct connection blocked. TURN is required"** | Both peers obtained public IP/port mappings, but Symmetric NAT / Carrier-Grade NAT (CGNAT) blocked direct UDP packets. A TURN server (Coturn) is mandatory for this network topology. |
| `candidates generated`, but `notify_call_members` HTTP status != 200 | **"Signaling bug: candidates not delivered to Odoo"** | Odoo rejected signaling payload (expired session cookie, invalid channel ID, or controller exception). |

### At the End of Every Call:
When hanging up, `pc.getStats()` inspects the active candidate pair and logs:
```
[STATS] Selected candidate pair: localType=srflx, remoteType=srflx, protocol=udp, relayProtocol=none
```
This tells you explicitly whether direct P2P (`srflx`) or relay (`relayProtocol=udp/turn`) carried the audio.

---

## 6. Assumptions Made About Odoo's RTC Protocol

Please verify these assumptions against your specific Odoo deployment:

1. **Odoo Version**:
   - Designed to support **Odoo 17.0 and 18.0** Discuss architecture.
   - Uses `/mail/rtc/channel/join_call` which returns `{ sessionId, rtcSessions, iceServers }` (with fallback to Odoo 18 Store structure).
2. **Authentication**:
   - Assumes standard Odoo JSON-RPC authentication at `/web/session/authenticate` with `db`, `login`, `password`.
   - The session cookie `session_id` is extracted and attached via `Cookie: session_id=<sid>` to all subsequent HTTP requests and WebSocket handshakes.
3. **WebSocket Bus Protocol**:
   - WebSocket endpoint is at `wss://<host>/websocket` (or `ws://` if HTTP).
   - Handshake sends `Origin: <baseUrl>` (required by Odoo to prevent 400 Bad Request) and `ngrok-skip-browser-warning: true`.
   - Subscription frame format:
     ```json
     {
       "event_name": "subscribe",
       "data": {
         "channels": ["discuss.channel_<id>", "channel_<id>"],
         "last": 0
       }
     }
     ```
   - Peer notifications arrive under bus type: `"discuss.channel.rtc.session/peer_notification"` with payload `{ sender: int, notifications: [string] }`.
4. **Signaling Payload Format (`notify_call_members`)**:
   - Endpoint: `/mail/rtc/session/notify_call_members`.
   - Parameter structure:
     `peer_notifications = [ [senderSessionId, [targetSessionIds], json_string_content] ]`
   - Content JSON structure:
     `{"event": "offer"|"answer"|"ice-candidate"|"disconnect", "channelId": channelId, "payload": {...}}`
5. **Polite Peer Collision Rule**:
   - If an offer collision occurs (`signalingState != stable`), the peer with the **higher session ID** behaves as the polite peer and rolls back to accept the incoming offer.
