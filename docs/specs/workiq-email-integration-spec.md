# WorkIQ Email Integration Spec

**Owner:** FI (Data Lead)
**Requested by:** FR (Research Lead) - T7
**Purpose:** Define how AI Maker handles "summarize my emails" requests - what fields to surface, what to suppress, and what the output format looks like for a non-technical user.

---

## Request Types

WorkIQ email requests fall into three categories:

| Category | Example | Frequency (estimated) |
|----------|---------|----------------------|
| Full inbox summary | "What do I need to know from my email today?" | High |
| Thread summary | "What happened in the Azure conversation?" | High |
| Action extraction | "What do I need to respond to?" | Medium |
| Sender focus | "Anything from Satya this week?" | Medium |
| Priority filter | "What's urgent?" | Low |

---

## Fields to Surface

For each email in the summary, AI Maker surfaces these fields from the Graph API response:

| Field | Source | Display | Notes |
|-------|--------|---------|-------|
| Sender name | `from.emailAddress.name` | Always | Prefer display name, never raw email for main view |
| Subject | `subject` | Always | Truncate at 80 chars with ellipsis |
| Received time | `receivedDateTime` | Always | Relative: "2 hours ago", "Yesterday", "Monday" |
| Preview | `bodyPreview` | Summarized | AI Maker writes a 1-sentence summary, not raw preview |
| Importance | `importance` | Conditional | Only surface if `importance === "high"` |
| Read status | `isRead` | Conditional | Surface only unread count in header, not per-email |
| Thread depth | derived from `conversationId` | Conditional | Show "N replies" if thread has multiple messages |

---

## Fields to Suppress

These fields exist in the Graph API response but must NOT appear in WorkIQ output:

| Field | Reason |
|-------|--------|
| Raw email addresses | Privacy: use display names only |
| Full body HTML/text | Too long; AI Maker summarizes instead |
| Message ID / conversation ID | Internal plumbing, not useful to user |
| `@odata.etag` and internal metadata | Irrelevant |
| BCC recipients | Privacy |
| Internet message headers | Technical noise |
| Attachment file paths | Surface count only ("2 attachments"), not paths |

---

## Output Format

### Full Inbox Summary

```
You have 12 unread emails. Here are the ones that matter:

From Kai (10 min ago): Asking about the algebra homework - wants to know if the Khan Academy session counts toward today's goal.

From Priya Nair (1 hour ago): Status update on the Azure migration. The database cutover is scheduled for Friday. She needs your approval by tomorrow noon.

From the AI Maker team (2 hours ago): Sprint 4 retrospective notes are ready for your review.

3 more unread from marketing lists - skipped.
```

Key rules:
- Lead with the unread count.
- Group by importance: high-importance first, then time-ordered.
- Suppress mailing lists and newsletters (detected by sender domain patterns or list-unsubscribe headers).
- Combine "3 more from [category]" at the end rather than enumerating them.
- Never read the email body verbatim - always paraphrase.
- Cap at 6 email summaries per request. Offer to show more.

### Thread Summary

```
The Azure migration thread has 8 messages over 3 days.

Summary: Priya kicked it off Monday asking about the database timeline. You responded Tuesday confirming the Friday window. Today, she's following up asking for written approval by tomorrow noon because the vendor needs it.

Action needed: Reply to Priya with approval.
```

Key rules:
- State participant count and time span.
- Summarize arc of the conversation (not each message).
- Extract the current action item explicitly.

### Action Extraction

```
3 emails need a response from you:

1. Priya Nair - Azure approval by tomorrow noon
2. Kai - Homework question (low urgency)
3. Design team - Feedback on the deck (they asked by Friday)

Want me to draft any of these?
```

Key rules:
- Sort by deadline, then by importance.
- Include soft deadlines extracted from body ("by Friday" counts).
- Offer to draft. Do not draft unless asked.

---

## Graph API Query Parameters

For inbox summary, FI recommends this Graph query:

```
GET /me/mailFolders/inbox/messages
  ?$select=id,subject,from,receivedDateTime,bodyPreview,importance,isRead,conversationId
  &$filter=receivedDateTime ge {24-hours-ago}
  &$orderby=receivedDateTime desc
  &$top=50
```

Rationale:
- `$select` avoids pulling full body (performance, privacy).
- Filter to last 24 hours for daily summary. Extend to 7 days for weekly.
- `$top=50` caps cost. AI Maker summarizes further.

---

## Privacy Rules

These rules apply to all email handling in WorkIQ, non-negotiable:

1. **No verbatim body text** in any output. Always paraphrase.
2. **No email addresses** in user-visible output. Display names only.
3. **No BCC exposure**. BCC fields must never be mentioned.
4. **No attachment content.** Count only ("2 attachments").
5. **No forwarding.** WorkIQ cannot forward or share emails.
6. **User consent gate.** First-time email access requires explicit "yes, access my email" confirmation from user.
7. **Scope display.** When email access is first granted, tell user exactly what WorkIQ can and cannot see.

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Empty inbox | "Your inbox is clear for the last 24 hours." |
| Only newsletters | "Nothing urgent. 14 newsletters received - want a summary of any?" |
| Email from Marcus (user) themselves | Skip (sent items, not received) |
| Encrypted email | "1 encrypted email from [Name]. I cannot read its contents." |
| Calendar invite in inbox | Treat as email, note it's an invite: "Meeting invite from [Name]: [Subject]" |
| Email with no subject | Use "(No subject)" in summary |
| Very long thread (50+ messages) | Summarize the last 5 messages only, note thread is long |

---

## FR Notes

- This spec covers read-only access. Write/send is out of scope for v1.
- The "offer to draft" feature is in scope but needs a separate spec (FI can write on request).
- Mailing list detection heuristic: `list-unsubscribe` header present, or sender domain matches known marketing domains.
- Importance classification: use Graph `importance` field first. If "normal", apply FI's recency + sender-rank signal to boost or suppress.
