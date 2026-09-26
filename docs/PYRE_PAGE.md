# The Pyre — Product Contract

The Pyre is PyreChat's shared live hangout. It is intentionally **not** another
engagement feed.

## Core behavior

- You deliberately enter The Pyre.
- People can see that you are actually there while you are present.
- You chat while you are there.
- Entering and leaving may appear as lightweight room events ("Max pulled up a
  chair", "Max headed out").
- Leaving means leaving. The product should not guilt, streak, badge, or buzz the
  user back into the room.
- **The Pyre never sends message/activity notifications.**
- Direct chats, account activity, and safety events remain separate systems.

## UX tone

The room should feel like arriving at a warm place where people are already
hanging out, not opening a content feed. Prefer presence, motion, spatial warmth,
and human-scale conversation over counters, engagement statistics, unread
pressure, or infinite-history mechanics.

## History

The desired product behavior is live-session-first. The backend contract still
needs to decide exactly how much recent context is delivered to someone who just
arrived. Do not invent persistence semantics in the client.

## Backend contract still required

Before the client becomes a real multi-user room, the server needs explicit
contracts for:

- join / leave presence;
- current participant roster;
- live room messages;
- reconnect and stale-presence expiry;
- moderation / block / report behavior;
- retention / recent-context semantics;
- rate limiting and abuse handling.

No endpoints or WebSocket event names are assumed here.

## Avatar direction

Pyre identity should support multiple avatar providers behind one app-owned
avatar model. A Snapchat-linked Bitmoji can be one optional source, but PyreChat
accounts and navigation remain independent of Snapchat/Camera Kit.

The current client accepts an optional avatar URL with a normal Pyre fallback.
Snap Login Kit or another approved identity integration can populate that later.
Camera Kit remains an optional AR runtime for camera experiences, not the owner
of Pyre identity or social state.
