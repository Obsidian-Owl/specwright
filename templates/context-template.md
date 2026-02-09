# {MODULE_NAME} Context

> **Purpose**: {ONE_SENTENCE_DESCRIPTION}
> **Bounded Context**: {DOMAIN_THIS_MODULE_OWNS}
> **Last Updated**: {DATE}

## Module Boundaries

### What This Module Owns
- {DOMAIN_CONCEPT_1}
- {DOMAIN_CONCEPT_2}

### What This Module Does NOT Own
- {RELATED_CONCEPT_OWNED_BY_OTHER_MODULE}

### Dependencies
| Module | Relationship | Communication |
|--------|-------------|---------------|
| {MODULE} | {WHY_NEEDED} | {API/Event/Import} |

---

## Domain Models

### Core Entities
- {ENTITY_NAME}: {DESCRIPTION}

### Integration Contracts
> If other modules need data from this module, define explicit contracts.
> Do NOT share internal models across module boundaries.

---

## External Integration Patterns

### {PROVIDER_NAME} (if applicable)

#### Key Patterns
- {PATTERN_DESCRIPTION}

#### Error Handling
| External Error | Domain Error | Handling |
|----------------|-------------|----------|
| {ERROR} | {MAPPED_ERROR} | {ACTION} |

---

## Event Contracts (if applicable)

### Events This Module Publishes
| Event | Payload | When Published |
|-------|---------|----------------|
| {EVENT_NAME} | {PAYLOAD_TYPE} | {TRIGGER} |

### Events This Module Consumes
| Event | Source | Handler |
|-------|--------|---------|
| {EVENT_NAME} | {SOURCE_MODULE} | {HANDLER_NAME} |

---

## Test Patterns

### Test Data
- {DESCRIPTION_OF_TEST_DATA_APPROACH}

---

## Quality Gates

Before marking work complete:
- [ ] Build succeeds
- [ ] Module tests pass
- [ ] {DOMAIN_SPECIFIC_CHECK}

---

## Common Pitfalls

### Do NOT
1. {ANTI_PATTERN}

### Instead
1. {CORRECT_PATTERN}
