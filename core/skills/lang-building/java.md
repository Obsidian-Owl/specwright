# Java Implementation Patterns

Language-specific patterns for Java projects. Loaded by sw-build into agent context.

## Idioms

### Optional
- Use `Optional<T>` for return types that may be absent. Never use `null` for "no result."
- Never use `Optional` as a method parameter or field type — it's for return values only.
- Chain with `.map()`, `.flatMap()`, `.orElse()`. Avoid `.get()` without `.isPresent()`.
- Use `.orElseThrow(() -> new NotFoundException(...))` for required values.

### Streams
- Use streams for collection transformations: `.filter()`, `.map()`, `.collect()`.
- Prefer `Collectors.toList()` (or `.toList()` in Java 16+) over manual accumulation.
- Use `Stream.of()` for small inline collections. Use `.flatMap()` for nested collections.
- Avoid side effects in stream operations. Streams should be pure transformations.

### Records (Java 16+)
- Use records for immutable data carriers: `record User(String name, String email) {}`.
- Records auto-generate `equals()`, `hashCode()`, `toString()`, and accessors.
- Use compact constructors for validation: `record Age(int value) { Age { if (value < 0) throw ...; } }`.
- Records cannot extend classes but can implement interfaces.

### Error Handling
- Use checked exceptions for recoverable conditions, unchecked for programming errors.
- Wrap low-level exceptions with domain-specific ones: `throw new OrderException("...", cause)`.
- Use try-with-resources for all `AutoCloseable` resources.
- Never catch `Exception` or `Throwable` broadly. Catch specific exception types.
- Never swallow exceptions in empty catch blocks. At minimum, log and rethrow.

## Type Patterns

- Use interfaces for contracts. Implementations are package-private when possible.
- Use sealed interfaces/classes (Java 17+) for closed type hierarchies with pattern matching.
- Use generics with bounds: `<T extends Comparable<T>>` for constrained types.
- Prefer composition over inheritance. Use delegation, not deep class hierarchies.

## Framework Conventions

### Spring Boot
- Use constructor injection, not field injection (`@Autowired` on fields). Constructor injection is testable and makes dependencies explicit.
- Use `@Service`, `@Repository`, `@Controller` stereotypes for clear layer separation.
- Use `@Transactional` at the service layer, not the repository layer.
- Use `@ConfigurationProperties` for typed configuration. Avoid `@Value` for complex config.
- Use `@SpringBootTest` for integration tests. Use `@DataJpaTest`, `@WebMvcTest` for slice tests.
- Define bean lifecycle with `@PostConstruct` / `@PreDestroy` or `InitializingBean`.

### JUnit 5
- Use `@Nested` for grouping related tests within a class.
- Use `@ParameterizedTest` with `@MethodSource` or `@CsvSource` for data-driven tests.
- Use `@BeforeEach` / `@AfterEach` for test setup. Use `@BeforeAll` only for expensive shared fixtures.
- Use AssertJ fluent assertions: `assertThat(result).isEqualTo(expected)` over JUnit's `assertEquals`.

### Dependency Injection
- Bind interfaces to implementations in configuration classes, not inline.
- Use `@Qualifier` when multiple implementations exist. Use `@Primary` for the default.
- Use `@Profile` for environment-specific beans (dev, test, prod).

## Anti-Patterns

- **Null returns**: Return `Optional<T>` or throw, never `null`. Null is a bug waiting to happen.
- **God classes**: Classes with >300 lines or >10 methods need splitting. Single responsibility.
- **Primitive obsession**: Use domain types (`Money`, `Email`, `OrderId`), not raw `String`/`int`.
- **Checked exception abuse**: Don't declare checked exceptions for conditions the caller can't handle. Use unchecked (RuntimeException) for programming errors.
- **Static utility classes**: Prefer instance methods with dependency injection. Static methods are untestable.
- **Lombok overuse**: `@Data` generates mutable objects with setters. Prefer `@Value` (immutable) or records. Don't use `@SneakyThrows` — it hides exception handling.
