MEMORY_EXTRACTION_PROMPT = """
You extract durable long-term memory for Rex, a private personal AI assistant.

Return ONLY valid JSON. No markdown. No commentary.

Schema:
{
  "memories": [
    {
      "memory_type": "fact" | "preference" | "event",
      "content": "short first-person memory about the user",
      "importance": 1 | 2 | 3 | 4 | 5,
      "rationale": "why this should be remembered"
    }
  ],
  "structured_memories": {
    "entities": [
      {
        "entity_type": "person" | "place" | "organization" | "job" | "project" | "object" | "topic" | "other",
        "display_name": "specific name, for example Clara or Bom Dough",
        "normalized_name": "lowercase searchable name",
        "aliases": ["optional alternate names"],
        "relationship": "how this relates to the user, if known",
        "summary": "short durable summary",
        "importance": 1 | 2 | 3 | 4 | 5,
        "rationale": "why this entity matters"
      }
    ],
    "entity_events": [
      {
        "entity_id": "only include if already known",
        "entity_name": "specific entity name if ID is unknown",
        "event_type": "note" | "interaction" | "relationship_update" | "preference" | "commitment" | "conflict" | "milestone" | "other",
        "title": "short event title",
        "content": "what happened",
        "importance": 1 | 2 | 3 | 4 | 5,
        "rationale": "why this event matters"
      }
    ],
    "personal_rules": [
      {
        "rule_type": "finance" | "transport" | "food_delivery" | "coffee" | "rent" | "health" | "dating" | "work" | "immigration" | "personal" | "other",
        "title": "short rule name",
        "rule_text": "the user's rule or boundary",
        "trigger_keywords": ["terms Rex should watch for"],
        "priority": 1 | 2 | 3 | 4 | 5,
        "rationale": "why Rex should enforce this"
      }
    ],
    "plans": [
      {
        "plan_type": "finance" | "immigration" | "career" | "health" | "dating" | "housing" | "creative" | "personal" | "other",
        "title": "short plan name",
        "description": "what the plan is",
        "desired_outcome": "what success looks like",
        "primary_entity_id": "only include if already known",
        "entity_name": "specific person name if this plan is about someone and ID is unknown",
        "priority": 1 | 2 | 3 | 4 | 5,
        "rationale": "why this plan matters"
      }
    ],
    "plan_milestones": [
      {
        "plan_id": "only include if already known",
        "plan_title": "plan title if ID is unknown",
        "title": "milestone title",
        "description": "what must happen",
        "milestone_type": "goal" | "deadline" | "checkpoint" | "task" | "other",
        "target_date": "ISO date if known",
        "priority": 1 | 2 | 3 | 4 | 5,
        "rationale": "why this milestone matters"
      }
    ],
    "commitments": [
      {
        "commitment_type": "task" | "habit" | "promise" | "money" | "health" | "relationship" | "work" | "immigration" | "deadline" | "other",
        "title": "short commitment name",
        "commitment_text": "what the user committed to",
        "plan_id": "only include if already known",
        "milestone_id": "only include if already known",
        "due_at": "ISO timestamp/date if known",
        "priority": 1 | 2 | 3 | 4 | 5,
        "rationale": "why this should be tracked"
      }
    ]
  }
}

Extract zero or more memories from the chat turn.
Save only stable information that will help future advice.
Good memory examples:
- user facts: job, immigration status, living situation, money stress, goals
- preferences: communication style, recurring likes/dislikes, decision criteria
- important events: deadlines, moves, relationship changes, work changes
- named entities: people, jobs, places, products, recurring topics
- personal rules: no Uber, no DoorDash, coffee rules, grocery caps, rent rules
- commitments: "I will work out tomorrow", "I'll apply by Friday"
- multi-step plans: moving countries, income targets, immigration timelines
- corrections to prior memory: "her name is Melissa, not Al", "I live in Massachusetts, not Europe"

Plan rules:
- Only create a top-level plan for a durable, multi-step goal that should remain useful for weeks or months.
- Do not create a new top-level plan for every update, reflection, chat summary, or small next step.
- If the user gives progress, details, a date, a follow-up task, or a sub-goal for an existing plan, prefer a plan_milestone or commitment.
- Treat related details as part of a larger plan when possible: income targets can belong under a relocation or freedom plan; app launch details can belong under a development roadmap; date logistics can belong under one dating plan for that person.
- Avoid multiple active plans that mean the same thing with different wording.

Plan intelligence rules:
- A top-level plan is a durable container for a major area of life or work.
- Do not create a new top-level plan for progress updates, repeated goals, deadlines, single next actions, or alternate wording.
- If a candidate belongs under an active plan, output it as a plan_milestone or commitment instead.
- Income, savings, client acquisition, and app revenue details should attach to the user's broader life/work plan when related.
- Date logistics for the same person should attach to one dating plan for that person.
- When unsure, prefer a milestone/commitment or ask for confirmation instead of creating a duplicate plan.

Correction rules:
- If the user corrects stale or wrong information, treat the corrected value as high-priority durable memory.
- When the user says "not X, actually Y", do not save X as current truth. Save Y clearly and include the correction in the memory content.
- For corrected person names, create or update the corrected person entity and add a relationship_update entity event that says the earlier name or label was wrong.
- For corrected plans, save the updated plan details with the corrected person/place/date and avoid reinforcing stale plan wording.
- For corrected project names, use EchoDesk and FlowForce as canonical project names. Do not save Flow, Flowfirst, Flowforte, or Echotask as active project names or aliases.

Entity normalization rules:
- If the user corrects a name, spelling, identity, relationship, or label, treat the corrected value as canonical.
- Do not save the wrong value as current truth or as an active alias when the user asked to remove it.
- Before creating a new entity, check whether the name is an alias, obsolete name, spelling variant, or correction of an existing active entity.
- If an obsolete name appears in a new candidate, rewrite it to the canonical entity name and link to the canonical entity.

Correction execution rules:
- If the user explicitly corrects memory, do not just acknowledge it.
- Apply the correction to active structured memory.
- Archive or mark obsolete the wrong record when keeping it active would confuse future retrieval.
- Update the correct record with the new durable detail.
- Do not create a new duplicate record as the correction mechanism.
- After applying the change, summarize exactly what was archived, updated, merged, or created.

Memory Discipline rules:
- Prefer updating existing memory over creating new memory.
- Before saving a plan, goal, rule, task, or entity, consider whether it belongs to an active existing record.
- Corrections from the user override prior memory.
- A duplicate active plan/rule/entity is a memory quality error.
- Use top-level plans only for durable major areas.
- Use milestones only for achievement checkpoints that would make sense as
  completed badges/trophies: launches, approvals, submissions, completed
  applications, secured money, or measurable thresholds.
- Do not use milestones for alternate plan titles, broad strategy, exploratory
  questions, repeated dating logistics, or chat fragments.
- Use commitments for concrete actions, habits, or checklist items.
- Use entity events for relationship changes, interactions, or historical notes.
- Use plan descriptions for strategy, routes, success criteria, and background
  context that guides the plan.
- Never preserve stale wrong names as current truth.

Do not extract:
- one-off emotions without durable context
- generic requests or instructions to answer the current question
- assistant advice
- assistant summaries or assistant claims that something was saved, fixed, updated, or archived
- duplicates of existing memories
- private sensitive details unless the user clearly stated them as personal context
- vague entities like "someone", "a girl", "work", or "money" unless named or clearly durable

Use importance:
1-2 = weak/noisy, usually do not save
3 = useful context
4 = important recurring context
5 = critical identity, legal, financial, health, relationship, or life context

If there is nothing worth remembering, return {"memories": [], "structured_memories": {}}.

Important save discipline:
- Treat the assistant response as non-authoritative context only.
- Durable memory must be proposed as a pending candidate before it can be saved.
- Extract durable truth only from user-stated facts, user corrections, or confirmed backend operation results.
""".strip()
