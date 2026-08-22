## Skills, Plugins, MCP & Tool Usage

AI agents must actively use available skills, plugins, MCP servers, sub-agents, tools, and repository-specific capabilities when they materially improve the quality, correctness, speed, safety, or completeness of the assigned task.

Before implementing a task:

1. Inspect which skills, plugins, MCP tools, agent tools, and integrations are currently available in the environment.

2. Read the instructions for any relevant installed skill or plugin before using it.

3. If an installed skill, plugin, MCP server, or specialized tool is relevant to the current task, prefer using it instead of manually recreating the same capability.

4. Use specialized tools where appropriate, including but not limited to:

   * UI/UX and design skills for frontend implementation.
   * Testing and browser automation tools for UI and end-to-end verification.
   * Documentation skills for technical documentation.
   * Database tools for schema inspection, migrations, and validation.
   * API tools for API inspection and testing.
   * Security tools for authentication, authorization, dependency, and vulnerability review.
   * Git/GitHub tools for repository inspection and pull-request workflows.
   * Mobile/Flutter skills for mobile-specific work.
   * Backend/framework-specific skills for server-side work.
   * Search/research tools when current external documentation is necessary.
   * MCP servers or connected services when they provide authoritative project or platform information.

5. Do not use every available tool unnecessarily. Select only the tools that provide meaningful value for the current task.

6. Agents may combine multiple relevant skills or plugins when a task spans multiple domains. For example, a frontend task may require UI design guidance, implementation tooling, browser testing, accessibility checks, and code-quality validation.

7. Do not assume a required capability is unavailable before checking the installed skills, plugins, MCP servers, and tools.

8. When a relevant installed capability exists, use it according to its own instructions and constraints.

9. If a useful tool or skill is available but cannot be used because of missing configuration, permissions, credentials, or dependencies, record the limitation rather than silently ignoring it.

10. Never install a new plugin, package, MCP server, extension, external service, or dependency merely because it may be useful. New installations still require the approvals defined elsewhere in this repository.

11. Tool usage must obey all repository security, privacy, Git, architecture, and command-safety rules. Availability of a tool does not override those rules.

12. Do not expose secrets, credentials, environment variables, private project information, or sensitive data to external tools or services.

13. Prefer read-only inspection tools before tools that mutate files, repositories, databases, cloud resources, or external systems.

14. For UI implementation tasks, read `DESIGN.md` first and use any relevant installed UI/UX or frontend skills before making design decisions.

15. For tasks involving unfamiliar frameworks, libraries, APIs, SDKs, or platform behavior, use relevant documentation/research tools rather than relying on assumptions.

16. For verification, use the strongest relevant available capability where practical—for example:

    * unit/integration tests for logic,
    * browser automation for web flows,
    * device/emulator tests for mobile flows,
    * API testing for backend endpoints,
    * lint/type checks for static correctness,
    * security checks for sensitive changes.

17. If multiple tools can perform the same job, prefer the one that:

    * is already installed and trusted,
    * is most specific to the task,
    * introduces the least risk,
    * requires the fewest unnecessary changes,
    * and provides reproducible results.

18. The agent's final report should mention important specialized skills/tools used when they materially contributed to implementation or verification.

### Tool Discovery Rule

Do not begin substantial implementation blindly.

For each assigned task, first determine:

```text
What installed skills, plugins, MCP servers, tools, or specialized agents
can materially help complete or verify this task?
```

Use the relevant ones when needed.

The rule is:

```text
USE AVAILABLE SPECIALIZED CAPABILITIES WHEN THEY ADD VALUE.
DO NOT USE TOOLS JUST FOR THE SAKE OF USING TOOLS.
DO NOT REIMPLEMENT A CAPABILITY THAT AN APPROVED INSTALLED TOOL
ALREADY PROVIDES BETTER.
```

### Example Agent Workflow

```text
Read AGENTS.md and PROJECT_TASKS.md.

Identify the assigned eligible task.

Inspect relevant installed skills, plugins, MCP servers, and tools.

Read the instructions of capabilities relevant to the task.

Read project files and DESIGN.md if UI is involved.

Use the relevant capabilities during implementation and verification.

Complete exactly one task.

Run the strongest relevant validation available.

Update PROJECT_TASKS.md.

Report:
- what changed,
- which relevant tools/skills were used,
- what was validated,
- and any remaining limitations.

Do not start another task.
```
