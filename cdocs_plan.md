# cdocs plan

CDocs is a doc structure and collection of claude skills for organizing work, reports etc.

I've copied some markdown and structure from a project, and want to refine it into a full-fledged claude plugin.

Please take the structure and markdown in this repo, along with this plan/notes doc, and make a concrete proposal for reworking them into skills, plugins, hooks as appropiate.
Note that not everything has to be sorted by the proposal, but it should lay out a sufficiently detailed layout and plan of attack for researching & completing the necessary elements for our plugin.

The proposal should specify what claude "tasks" you recommend we create as well.

Note that there is likely unaccounted for process-level conventions I've been using, like template prompts for proposals and reviews.
We'll want to take note of them for expansion later.



## general directives

### frontmatter
Every cdoc should have have frontmatter with the following fields:

```yaml
---
review_of?: cdocs/.../2026-01-29_doc_name.md
first_authored:
  by: @claude-opus-4-5-20251101
  at: 2026-01-29T08:00:00-08:00
task_list: organization/initial_scaffolding
type: devlog | proposal | ... 
state: live | deferred | archived
status: wip | done ...
last_reviewed?: unready | requested |
  status: revision_requested | accepted | rejected ...
  by: @mjr | @claude-opus-4-5-20251101 ...
  at: 2026-01-29T09:00:00-08:00
  round: 1
tags: [future_work, handoff, architecture, electron, claud_skills, ...]
---
```

More details on the above fields:
1. review_of: only for reviews, path to subject doc from repo-root
2. first_authored:
   - by: full api-valid model name of the agent who first wrote the document, or user-@
   - at: must include tz relativity so it is maximally useful to the user.
3. task_list:
   - claude task list tracking / connections for a constrained/inter-related arc of work.
   - `/` namespacing is recommended to tacitly capture workstream heirarchy.
4. type: correspond to each subdir under cdocs. May be expanded in the future
5. state: current high-level condition of the document and/or it's related work.
6. status: options depend on the type, but always start with `wip`.
  additional statuses:
  - `review_ready`:
    - devlogs, proposals, and reports use this to mark their SoW fully complete and ready for review.
    - for devlogs, reviews apply to the work that was done
  - `implementation_ready`: proposal design accepted, ready to implement
  - `evolved`, `implementation_accepted`: proposals often two phased and the work might result in a new evolved proposal
7. last_reviewed: reviews themselves don't have this field.
   - status: options may be expanded depending on type
   - by, at: same as in first_authored
   - how many rounds of review have occurred
8. tags: limited freeform set of the most relevant topics the doc concerns.
   - reviews should use tags like `self`, `fresh_agent`, `rereview_agent`, `runtime_validated`, `ui_validated`, `architecture`
   - proposals might get spun off as `future_work` `state:deferred`

### filenaming
Always use `{date}_{snake_case}.md` names as specified elsewhere for each file type.

### media
media should always be dated, saved to `cdocs/_media`, and embedded into the relevant doc.

### writing conventions
we want to break the general high-level communication and documentation directives into a resource for reference by all our skills to encourage uniform, professional writing.

We'll also likely be adding more syntax features and markdown extensions as idioms to our system, and we'll want them to be a shared resource.

## re-org, stubbing
We have some specific directives in the CLAUDE.md that should be put into skills or whatever idiomatic resource is approproate.
For types we don't have detailed specs for yet like reviews and reports, the (sub)agent responsible should do some research on best practices / recommended processes when working with claude, but we want to avoid overly-rigid structures I think.

## probable future work

### automations 
1. we'll want to add some hook for formatting the markdown, esp for table spacing and aligning boxes in the `|`-contained diagrams claude likes to make (should opt for adding padding chars to avoid mangling text) 
2. some features might start as broad directives but be boiled down into skills, hooks, etc
3. we'll want a cli for working with the docs as if they're a db.
4. we'll want a skill for setting up the scaffolding for cdocs in a repo, and updating the CLAUDE.md with stuff that doesn't make sense to be tucked in a skill 

We might want to turn the repo into a claude plugin marketplace rather than a single plugin, not sure. Can figure out later.

We also might want a way of quickly adding to the metadata or taxonomy of our system, of overlaying a new convention over the plugin for experimentation then later integration, etc
