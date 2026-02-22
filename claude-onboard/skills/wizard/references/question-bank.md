# Wizard Question Bank

Complete catalog of questions with branching logic. The wizard skill selects and adapts questions based on codebase analysis results and prior answers.

---

## Category 1: Project Context (Always Ask)

### Q1.1: Project Description
**Ask**: "In a sentence or two, what does this project do?"
**Purpose**: Sets context for everything else. Used in root CLAUDE.md project overview.
**Map to**: `projectDescription`

### Q1.2: Team Structure
**Ask**: "Are you the sole developer, or do you work with a team?"
**Follow-up if team**: "Roughly how many developers? (2-5 / 6-15 / 15+)"
**Follow-up if team >5**: "Do you have shared coding standards or a style guide?"
**Purpose**: Determines agent complexity (solo = fewer agents, team = collaboration agents), rule strictness.
**Map to**: `teamSize`, and conditionally `sharedStandards`

### Q1.3: Project Maturity
**Ask**: "Would you describe this as a new project, something in active early development, an established codebase, or legacy code?"
**Skip if**: Analysis shows <10 source files (auto-classify as "new/early")
**Purpose**: Affects rule strictness, convention documentation depth.
**Map to**: `projectMaturity`

---

## Category 2: Development Workflow (Always Ask)

### Q2.1: Primary Work Types
**Ask**: "What kind of work do you primarily do here? Feature development, bug fixes, maintenance/refactoring, or a mix?"
**Purpose**: Determines which skills and agents are most valuable.
**Map to**: `primaryTasks`

### Q2.2: Code Review Process
**Ask**: "How do code reviews work? No formal process, informal peer review, or formal PR reviews?"
**Skip if**: Solo developer + analysis shows no PR-related CI
**Purpose**: Determines whether to generate review-focused agents and rules.
**Map to**: `codeReviewProcess`

### Q2.3: Branching Strategy
**Ask**: "What's your branching approach? Trunk-based, gitflow, feature branches, or something else?"
**Skip if**: Not a git repo, or analysis shows only main/master branch
**Infer from**: Git branch patterns detected in analysis
**Purpose**: Affects hook configurations and commit-related rules.
**Map to**: `branchingStrategy`

### Q2.4: Deploy Frequency
**Ask**: "How often do you deploy? Continuous, daily, weekly, manual, or not yet set up?"
**Skip if**: No CI/CD detected AND no deployment config found
**Purpose**: Affects CI/CD rules and deployment-related skills.
**Map to**: `deployFrequency`

---

## Category 3: Frontend-Specific (If Frontend Detected)

**Trigger**: Analysis detected React, Vue, Svelte, Angular, or significant HTML/CSS/JS frontend code.

### Q3.1: Component Patterns
**Ask**: "How do you organize your components? Atomic design, feature-based grouping, flat structure, or something else?"
**Skip if**: Analysis clearly shows the pattern (e.g., `atoms/`, `molecules/`, `organisms/` directories)
**Purpose**: Drives component-related rules and skills.
**Map to**: `frontendPatterns.componentOrganization`

### Q3.2: Styling Approach
**Ask**: "What's your styling approach?"
**Skip if**: Analysis detected a single clear styling solution (e.g., only Tailwind found)
**Offer choices based on detected tools**: Tailwind / CSS Modules / styled-components / Sass / other
**Purpose**: Styling-specific rules.
**Map to**: `frontendPatterns.styling`

### Q3.3: State Management
**Ask**: "How do you handle state management?"
**Skip if**: Analysis found a clear state management library
**Only ask if**: React or Vue detected (Svelte has built-in stores)
**Purpose**: State management conventions and rules.
**Map to**: `frontendPatterns.stateManagement`

---

## Category 4: Backend-Specific (If Backend Detected)

**Trigger**: Analysis detected Express, FastAPI, Django, Go server, Rust server, NestJS, or API routes.

### Q4.1: API Style
**Ask**: "What's your API style? REST, GraphQL, gRPC, or a mix?"
**Skip if**: Analysis clearly shows the style (e.g., GraphQL schema files found)
**Purpose**: API-specific rules and patterns.
**Map to**: `backendPatterns.apiStyle`

### Q4.2: Database Patterns
**Ask**: "How do you interact with your database? ORM, raw SQL, document store, or something else?"
**Skip if**: Analysis detected a specific ORM (Prisma, SQLAlchemy, etc.)
**Purpose**: Database interaction rules.
**Map to**: `backendPatterns.databaseApproach`

### Q4.3: Auth Approach
**Ask**: "What's your authentication approach? JWT, sessions, OAuth, or something else?"
**Only ask if**: Backend appears to have auth-related code
**Purpose**: Security rules and auth-related conventions.
**Map to**: `backendPatterns.authApproach`

---

## Category 5: DevOps-Specific (If CI/CD Detected)

**Trigger**: Analysis detected GitHub Actions, GitLab CI, CircleCI, Jenkins, or deployment configs.

### Q5.1: Deployment Target
**Ask**: "Where does this deploy? Cloud provider, self-hosted, serverless, or multiple targets?"
**Purpose**: Deployment-related rules and skills.
**Map to**: `devopsPatterns.deployTarget`

### Q5.2: Infrastructure as Code
**Ask**: "Do you use infrastructure as code? Terraform, Pulumi, CloudFormation, Docker Compose, or none?"
**Skip if**: Analysis didn't find any IaC files
**Purpose**: IaC-specific rules.
**Map to**: `devopsPatterns.iacTool`

---

## Category 6: Pain Points (Always Ask)

### Q6.1: Time Sinks
**Ask**: "What part of your development workflow takes the most time or feels most tedious?"
**Purpose**: Identifies highest-value automation opportunities. Directly influences which skills and agents to prioritize.
**Map to**: `painPoints.timeSinks`

### Q6.2: Error-Prone Areas
**Ask**: "What areas of the codebase or workflow are most error-prone?"
**Purpose**: Identifies where stricter rules and review agents would help most.
**Map to**: `painPoints.errorProne`

### Q6.3: Automation Wishes
**Ask**: "If Claude could automate one thing in your workflow, what would it be?"
**Purpose**: Direct input for skill and agent generation priorities.
**Map to**: `painPoints.automationWishes`

---

## Category 7: Preferences (Always Ask)

### Q7.1: Testing Philosophy
**Ask**: "How do you approach testing? TDD, write tests after implementation, minimal testing, or comprehensive coverage?"
**Purpose**: Calibrates testing rules strictness and test-writer agent behavior.
**Map to**: `testingPhilosophy`

### Q7.2: Code Style Strictness
**Ask**: "How strict should Claude be about code style and conventions? Relaxed (just make it work), moderate (follow conventions but don't nitpick), or strict (enforce everything)?"
**Purpose**: Calibrates rule strictness across all generated rules.
**Map to**: `codeStyleStrictness`

### Q7.3: Security Sensitivity
**Ask**: "How security-sensitive is this project? Standard (typical web app), elevated (handles user data/payments), or high (financial/healthcare/compliance)?"
**Purpose**: Determines whether to generate security-focused rules and agents.
**Map to**: `securitySensitivity`

### Q7.4: Claude Autonomy Level
**Ask**: "When working with Claude, do you prefer it to always ask before acting, take a balanced approach (ask for big decisions, act on small ones), or be as autonomous as possible?"
**Purpose**: This is the single most important preference. It shapes the tone and assertiveness of all generated CLAUDE.md content and rules.
**Map to**: `autonomyLevel`

---

## Branching Logic Summary

```
Analysis Results → Question Selection:

  frontend detected?
    YES → Ask Category 3 (skip questions answered by analysis)
    NO  → Skip Category 3

  backend detected?
    YES → Ask Category 4 (skip questions answered by analysis)
    NO  → Skip Category 4

  CI/CD detected?
    YES → Ask Category 5
    NO  → Skip Category 5

  solo developer?
    YES → Skip Q2.2 (code review), simplify Q2.3 (branching)
    NO  → Ask all Category 2

  <10 source files?
    YES → Auto-classify as "new", skip Q1.3
    NO  → Ask Q1.3
```

## Grouping Strategy

To keep the wizard to 5-6 exchanges:

1. **Exchange 1**: Q1.1 + Q1.2 + Q1.3 (Project Context — grouped together)
2. **Exchange 2**: Q2.1 + Q2.2 + Q2.3 + Q2.4 (Workflow — grouped together)
3. **Exchange 3**: Conditional tech-specific questions (Category 3/4/5 — only what applies)
4. **Exchange 4**: Q6.1 + Q6.2 + Q6.3 (Pain Points — grouped together)
5. **Exchange 5**: Q7.1 + Q7.2 + Q7.3 + Q7.4 (Preferences — grouped together)
6. **Exchange 6**: Summary & confirmation
