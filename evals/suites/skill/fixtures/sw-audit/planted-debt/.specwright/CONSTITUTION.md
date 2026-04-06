# Constitution

## Naming Conventions
- All source file names must use camelCase (e.g., `userHandler.ts`, not `user_handler.ts`).
- All exported functions must use camelCase.

## Architecture
- Circular dependencies between modules are prohibited.
- All exported functions must be imported by at least one consumer. No dead exports.
