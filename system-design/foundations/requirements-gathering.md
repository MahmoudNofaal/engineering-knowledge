# Requirements Gathering

> The process of extracting and clarifying what a system must do — and under what constraints — before any design decisions are made.

---

## When To Use It
Every system design starts here. Before drawing any diagrams or naming any technologies, you need to know what success actually looks like. Skip this and you'll design the wrong system confidently. It's especially critical in interviews, where the problem statement is intentionally vague — asking the right questions is part of what's being evaluated.

---

## Core Concept
Requirements gathering is how you turn a vague prompt ("design Instagram") into a set of concrete constraints you can build against. There are two types: functional requirements — what the system does (users can upload photos, follow other users) — and non-functional requirements — how well it does it (99.9% uptime, under 200ms latency, 50M DAU). The non-functional ones are harder to extract but they're what actually drive architecture choices. You ask questions, eliminate ambiguity, and write down explicit numbers before touching anything else.

---

## The Code
```python
# No code for requirements gathering itself — but here's a structured
# checklist you can internalize and run through mentally or on a whiteboard.

requirements = {
    "functional": [
        "What are the core user actions? (create, read, update, delete what?)",
        "What does the system NOT need to do? (explicitly out of scope)",
        "Are there any actors other than end users? (admins, third-party services)",
    ],
    "non_functional": [
        "How many daily active users?",
        "What is the read/write ratio?",
        "What latency is acceptable? (p99, not just average)",
        "What availability is required? (99.9% = 8.7hrs downtime/yr)",
        "Is the data consistency model eventual or strong?",
        "What is the expected data volume? (storage over 5 years)",
        "Is the system read-heavy, write-heavy, or balanced?",
    ],
    "constraints": [
        "Are there regulatory or compliance requirements? (GDPR, HIPAA)",
        "Is this greenfield or does it integrate with existing systems?",
        "Any hard technology constraints from the business?",
    ]
}
```
```python
# Translating gathered requirements into design inputs

reqs = {
    "dau": 50_000_000,
    "read_write_ratio": "100:1",
    "availability": "99.99%",     # ~52 minutes downtime/year — needs redundancy everywhere
    "latency_p99_ms": 300,
    "retention_years": 5,
    "avg_post_size_kb": 500,
}

writes_per_day = reqs["dau"] * 0.01          # ~500K writes/day (1% of users post)
storage_5yr_gb = (writes_per_day * reqs["avg_post_size_kb"] * 365 * reqs["retention_years"]) / 1e6
print(f"Storage needed (5yr): {storage_5yr_gb:,.0f} GB")
# This single output already tells you: object storage is mandatory, not optional.
```

---

## Gotchas
- **Availability numbers are not interchangeable.** 99.9% allows 8.7 hours of downtime per year. 99.99% allows 52 minutes. The gap between them is an entirely different architecture. Always clarify and write the number down.
- **"We need it to scale" is not a requirement.** Push for actual numbers — DAU, peak QPS, data volume. Vague scale talk leads to over-engineered systems that solve the wrong problem.
- **Functional requirements hide non-functional ones.** "Users can search" sounds functional, but it implies latency constraints, index freshness expectations, and a whole query engine decision. Unpack each feature.
- **Out-of-scope decisions are as important as in-scope ones.** Explicitly agreeing what the system won't do prevents scope creep mid-design and keeps the interview focused.
- **Don't gather requirements and then ignore them.** Every major component you add later should trace back to a stated requirement or constraint. If it doesn't, you're over-engineering.

---

## Interview Angle
**What they're really testing:** Whether you can operate under ambiguity without either freezing up or blindly charging ahead.

**Common question form:** The first 3–5 minutes of any system design interview. "Design X" — then silence.

**The depth signal:** A junior candidate starts drawing immediately or asks one generic question ("how many users?") and moves on. A senior candidate runs through a deliberate checklist — functional scope, non-functional numbers, consistency model, availability target — and writes the answers down visibly before touching the architecture. They also push back when numbers seem off ("50M DAU with 99.999% uptime is extremely expensive — is that a real constraint?"). The separation is: juniors accept the prompt as-is, seniors interrogate it.

---

## Related Topics
- [[system-design/back-of-envelope.md]] — Requirements feed directly into capacity estimation; you can't estimate without real numbers.
- [[system-design/cap-theorem.md]] — Consistency and availability requirements determine your position on the CAP triangle.
- [[system-design/what-is-system-design.md]] — The broader context this step sits inside.

---

## Source
https://www.educative.io/courses/grokking-modern-system-design-interview-for-engineers-managers

---
*Last updated: 2026-03-24*