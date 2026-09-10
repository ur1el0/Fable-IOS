# FABLE: Multi-Platform Architecture & Technical Specification
**Version:** 1.0.0  
**Target Platform:** Native iOS (SwiftUI, iOS 17+), Native Android (Jetpack Compose, Roadmapped), ASP.NET Core Minimal APIs (.NET 8/9), PostgreSQL, Docker  
**Date:** September 2026  
**Document Status:** Approved Architecture Blueprint  

---

## 1. Executive Summary & System Overview

### 1.1 Project Vision
**Fable** is a focused, multi-platform creative writing and serial micro-fiction reading platform designed for immersive reading and seamless manuscript authoring. Centered on folklore, urban legends, mythology, and serialized short fiction, Fable bridges native client experiences on mobile with a high-throughput, strongly typed backend service.

### 1.2 Target Milestones & Deliverables
The project lifecycle is split into two primary phases:

1. **Midterm Milestone (Target: September 17, 2026):**
   - **Functional Scope:** 50% core functional completion on native iOS.
   - **Architecture:** Strict Model–View–Controller (MVC) architecture using Swift 5.9+ / iOS 17+ (`@Observable` macro).
   - **User Interface:** Four core functional screens validated against 100% Figma prototype fidelity:
     - `StoryLibraryView`: Curated feed, hero spotlight card, genre filtering chips.
     - `StoryReaderView`: Immersive reading surface, serif typography controls, reading progress indicator.
     - `StoryComposerView`: Multi-field manuscript authoring form with live word count and field validation.
     - `StoryShelfView`: User collection tracking (Bookmarked / Completed) with segmented controls.
   - **Data Layer:** Decoupled in-memory mock repository inside `StoryController` ensuring 100% offline functionality.

2. **Final Milestone:**
   - **Backend Service:** ASP.NET Core Minimal APIs (.NET 8/9) containerized via Docker with PostgreSQL persistence via Entity Framework Core (EF Core).
   - **Full-Stack Integration:** Client-side HTTP networking layer using Swift `URLSession` async/await, integrating with backend endpoints.
   - **Cross-Platform Parity:** Roadmapped Android client leveraging Jetpack Compose, Kotlin Coroutines, and MVVM/MVI architectures reusing the identical REST contract.

---

## 2. High-Level System Architecture & Topology

Fable follows a decoupled client-server architecture. The mobile clients communicate with the backend via stateless, JSON-over-HTTPS REST APIs documented via OpenAPI 3.0 / Swagger.

```
       ┌────────────────────────────────────────────────────────┐
       │                     MOBILE CLIENTS                     │
       │                                                        │
       │   ┌────────────────────────┐  ┌────────────────────┐   │
       │   │  iOS Client (SwiftUI)  │  │  Android Client    │   │
       │   │  Architecture: MVC     │  │  (Jetpack Compose) │   │
       │   │  State: @Observable    │  │  Architecture: MVVM│   │
       │   └───────────┬────────────┘  └─────────┬──────────┘   │
       └───────────────┼─────────────────────────┼──────────────┘
                       │                         │
                       │ HTTPS / JSON REST APIs  │
                       ▼                         ▼
       ┌────────────────────────────────────────────────────────┐
       │                BACKEND REVERSE PROXY                   │
       │                (Kestrel / Nginx / Envoy)               │
       └───────────────────────────┬────────────────────────────┘
                                   │
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │            ASP.NET CORE 8/9 MINIMAL APIS               │
       │  ┌──────────────────────────────────────────────────┐  │
       │  │ Route Groups: /api/v1/stories, /api/v1/shelf     │  │
       │  ├──────────────────────────────────────────────────┤  │
       │  │ Middleware: Global Error Handling (RFC 7807),     │  │
       │  │             CORS, Rate Limiting, OpenAPI/Swagger │  │
       │  ├──────────────────────────────────────────────────┤  │
       │  │ Data Access: Entity Framework Core (Npgsql)      │  │
       │  └────────────────────────┬─────────────────────────┘  │
       └───────────────────────────┼────────────────────────────┘
                                   │
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │               PERSISTENCE LAYER (DOCKER)               │
       │                                                        │
       │   ┌────────────────────────────────────────────────┐   │
       │   │           PostgreSQL 16 (Relational DB)        │   │
       │   │  Tables: stories, genres, shelf_items, users   │   │
       │   └────────────────────────────────────────────────┘   │
       └────────────────────────────────────────────────────────┘
```

---

## 3. Type-Safe Contract Parity (C# ↔ Swift ↔ Kotlin)

To eliminate runtime serialization bugs and contract drift, DTOs (Data Transfer Objects) are defined using strict type mappings across C#, Swift, and Kotlin:

| Field | C# (.NET 8/9) | Swift (iOS 17+) | Kotlin (Android) | PostgreSQL Type |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `Guid` | `UUID` | `java.util.UUID` | `UUID (PRIMARY KEY)` |
| `title` | `string` | `String` | `String` | `VARCHAR(200)` |
| `author` | `string` | `String` | `String` | `VARCHAR(100)` |
| `genre` | `string` / `GenreEnum` | `Genre` (String Enum) | `Genre` (Enum) | `VARCHAR(50)` |
| `synopsis` | `string` | `String` | `String` | `TEXT` |
| `content` | `string` | `String` | `String` | `TEXT` |
| `readTimeMinutes` | `int` | `Int` | `Int` | `INTEGER` |
| `isBookmarked` | `bool` | `Bool` | `Boolean` | `BOOLEAN` |
| `isCompleted` | `bool` | `Bool` | `Boolean` | `BOOLEAN` |
| `createdAtUtc` | `DateTime` | `Date` (ISO 8601) | `java.time.Instant` | `TIMESTAMPTZ` |

### 3.1 C# Records & Data Transfer Objects
```csharp
namespace Fable.Core.Contracts;

public enum GenreType
{
    All,
    Folklore,
    Mythology,
    UrbanLegend,
    Horror,
    SciFi,
    Fantasy
}

public record StoryDto(
    Guid Id,
    string Title,
    string Author,
    string Genre,
    string Synopsis,
    string Content,
    int ReadTimeMinutes,
    bool IsBookmarked,
    bool IsCompleted,
    DateTime CreatedAtUtc
);

public record CreateStoryRequest(
    string Title,
    string Author,
    string Genre,
    string Synopsis,
    string Content,
    int ReadTimeMinutes
);

public record ShelfItemDto(
    Guid Id,
    Guid StoryId,
    string Title,
    string Author,
    string Genre,
    int ProgressPercentage,
    bool IsBookmarked,
    bool IsCompleted,
    DateTime LastReadAtUtc
);

public record PagedResult<T>(
    IReadOnlyList<T> Items,
    int PageNumber,
    int PageSize,
    int TotalCount,
    bool HasNextPage
);
```

### 3.2 Swift Codable Structs (iOS)
```swift
import Foundation

public enum Genre: String, CaseIterable, Codable, Identifiable {
    case all = "All"
    case folklore = "Folklore"
    case mythology = "Mythology"
    case urbanLegend = "Urban Legend"
    case horror = "Horror"
    case sciFi = "Sci-Fi"
    case fantasy = "Fantasy"

    public var id: String { rawValue }
}

public struct Story: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var author: String
    public var genre: Genre
    public var synopsis: String
    public var content: String
    public var readTimeMinutes: Int
    public var isBookmarked: Bool
    public var isCompleted: Bool
    public let createdAtUtc: Date

    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        genre: Genre,
        synopsis: String,
        content: String,
        readTimeMinutes: Int,
        isBookmarked: Bool = false,
        isCompleted: Bool = false,
        createdAtUtc: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.genre = genre
        self.synopsis = synopsis
        self.content = content
        self.readTimeMinutes = readTimeMinutes
        self.isBookmarked = isBookmarked
        self.isCompleted = isCompleted
        self.createdAtUtc = createdAtUtc
    }
}

public struct CreateStoryRequest: Codable {
    public let title: String
    public let author: String
    public let genre: String
    public let synopsis: String
    public let content: String
    public let readTimeMinutes: Int
}

public struct PagedResult<T: Codable>: Codable {
    public let items: [T]
    public let pageNumber: Int
    public let pageSize: Int
    public let totalCount: Int
    public let hasNextPage: Bool
}
```

---

## 4. PostgreSQL Relational Schema & EF Core Configuration

### 4.1 Relational DDL (PostgreSQL)
```sql
CREATE TABLE IF NOT EXISTS genres (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    slug VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    author VARCHAR(100) NOT NULL,
    genre_id INT NOT NULL REFERENCES genres(id) ON DELETE RESTRICT,
    synopsis TEXT NOT NULL,
    content TEXT NOT NULL,
    read_time_minutes INT NOT NULL DEFAULT 1,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at_utc TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS shelf_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    progress_percentage INT NOT NULL DEFAULT 0 CHECK (progress_percentage BETWEEN 0 AND 100),
    is_bookmarked BOOLEAN NOT NULL DEFAULT TRUE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    last_read_at_utc TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_shelf_story UNIQUE (story_id)
);

CREATE INDEX idx_stories_genre ON stories(genre_id);
CREATE INDEX idx_stories_created ON stories(created_at_utc DESC);
CREATE INDEX idx_shelf_items_status ON shelf_items(is_bookmarked, is_completed);
```

### 4.2 Entity Framework Core Model Mapping
```csharp
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Fable.Backend.Data;

[Table("stories")]
public class StoryEntity
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(200)]
    [Column("title")]
    public string Title { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    [Column("author")]
    public string Author { get; set; } = string.Empty;

    [Required]
    [MaxLength(50)]
    [Column("genre")]
    public string Genre { get; set; } = string.Empty;

    [Required]
    [Column("synopsis")]
    public string Synopsis { get; set; } = string.Empty;

    [Required]
    [Column("content")]
    public string Content { get; set; } = string.Empty;

    [Column("read_time_minutes")]
    public int ReadTimeMinutes { get; set; } = 1;

    [Column("is_published")]
    public bool IsPublished { get; set; } = true;

    [Column("created_at_utc")]
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    public virtual ShelfItemEntity? ShelfItem { get; set; }
}

[Table("shelf_items")]
public class ShelfItemEntity
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("story_id")]
    public Guid StoryId { get; set; }

    [ForeignKey(nameof(StoryId))]
    public virtual StoryEntity Story { get; set; } = null!;

    [Column("progress_percentage")]
    public int ProgressPercentage { get; set; } = 0;

    [Column("is_bookmarked")]
    public bool IsBookmarked { get; set; } = true;

    [Column("is_completed")]
    public bool IsCompleted { get; set; } = false;

    [Column("last_read_at_utc")]
    public DateTime LastReadAtUtc { get; set; } = DateTime.UtcNow;
}

public class FableDbContext : DbContext
{
    public FableDbContext(DbContextOptions<FableDbContext> options) : base(options) { }

    public DbSet<StoryEntity> Stories => Set<StoryEntity>();
    public DbSet<ShelfItemEntity> ShelfItems => Set<ShelfItemEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<StoryEntity>()
            .HasIndex(s => s.Genre);

        modelBuilder.Entity<StoryEntity>()
            .HasIndex(s => s.CreatedAtUtc);

        modelBuilder.Entity<ShelfItemEntity>()
            .HasIndex(si => new { si.IsBookmarked, si.IsCompleted });
    }
}
```

---

## 5. ASP.NET Core Minimal APIs Implementation

### 5.1 Program.cs Configuration
```csharp
using Fable.Backend.Data;
using Fable.Core.Contracts;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Database connection
builder.Services.AddDbContext<FableDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("FableDatabase")));

// OpenAPI / Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new() { Title = "Fable REST API", Version = "v1" });
});

// CORS for local multi-platform development
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowMobileDev", policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowMobileDev");

// Route Group: /api/v1/stories
var storyGroup = app.MapGroup("/api/v1/stories").WithTags("Stories");

// GET /api/v1/stories?genre=Folklore&search=forest&page=1&pageSize=20
storyGroup.MapGet("/", async (
    string? genre,
    string? search,
    int page = 1,
    int pageSize = 20,
    FableDbContext db = null!) =>
{
    var query = db.Stories.AsNoTracking().Where(s => s.IsPublished);

    if (!string.IsNullOrWhiteSpace(genre) && !genre.Equals("All", StringComparison.OrdinalIgnoreCase))
    {
        query = query.Where(s => s.Genre.ToLower() == genre.ToLower());
    }

    if (!string.IsNullOrWhiteSpace(search))
    {
        var term = search.Trim().ToLower();
        query = query.Where(s => s.Title.ToLower().Contains(term) || s.Synopsis.ToLower().Contains(term));
    }

    var totalCount = await query.CountAsync();
    var items = await query
        .OrderByDescending(s => s.CreatedAtUtc)
        .Skip((page - 1) * pageSize)
        .Take(pageSize)
        .Select(s => new StoryDto(
            s.Id,
            s.Title,
            s.Author,
            s.Genre,
            s.Synopsis,
            s.Content,
            s.ReadTimeMinutes,
            s.ShelfItem != null && s.ShelfItem.IsBookmarked,
            s.ShelfItem != null && s.ShelfItem.IsCompleted,
            s.CreatedAtUtc))
        .ToListAsync();

    return Results.Ok(new PagedResult<StoryDto>(
        items,
        page,
        pageSize,
        totalCount,
        (page * pageSize) < totalCount
    ));
});

// GET /api/v1/stories/{id:guid}
storyGroup.MapGet("/{id:guid}", async (Guid id, FableDbContext db) =>
{
    var story = await db.Stories
        .AsNoTracking()
        .Include(s => s.ShelfItem)
        .FirstOrDefaultAsync(s => s.Id == id);

    if (story is null) return Results.NotFound(new { message = $"Story {id} not found." });

    return Results.Ok(new StoryDto(
        story.Id,
        story.Title,
        story.Author,
        story.Genre,
        story.Synopsis,
        story.Content,
        story.ReadTimeMinutes,
        story.ShelfItem?.IsBookmarked ?? false,
        story.ShelfItem?.IsCompleted ?? false,
        story.CreatedAtUtc
    ));
});

// POST /api/v1/stories (Composer)
storyGroup.MapPost("/", async (CreateStoryRequest req, FableDbContext db) =>
{
    if (string.IsNullOrWhiteSpace(req.Title) || string.IsNullOrWhiteSpace(req.Content))
    {
        return Results.BadRequest(new { message = "Title and Content are required." });
    }

    var entity = new StoryEntity
    {
        Id = Guid.NewGuid(),
        Title = req.Title.Trim(),
        Author = string.IsNullOrWhiteSpace(req.Author) ? "Anonymous" : req.Author.Trim(),
        Genre = req.Genre.Trim(),
        Synopsis = req.Synopsis.Trim(),
        Content = req.Content.Trim(),
        ReadTimeMinutes = Math.Max(1, req.ReadTimeMinutes),
        CreatedAtUtc = DateTime.UtcNow
    };

    db.Stories.Add(entity);
    await db.SaveChangesAsync();

    var dto = new StoryDto(
        entity.Id, entity.Title, entity.Author, entity.Genre,
        entity.Synopsis, entity.Content, entity.ReadTimeMinutes,
        false, false, entity.CreatedAtUtc
    );

    return Results.Created($"/api/v1/stories/{entity.Id}", dto);
});

// Route Group: /api/v1/shelf
var shelfGroup = app.MapGroup("/api/v1/shelf").WithTags("Shelf");

// GET /api/v1/shelf?filter=bookmarked
shelfGroup.MapGet("/", async (string? filter, FableDbContext db) =>
{
    var query = db.ShelfItems.AsNoTracking().Include(si => si.Story).AsQueryable();

    if (filter?.ToLower() == "completed")
    {
        query = query.Where(si => si.IsCompleted);
    }
    else
    {
        query = query.Where(si => si.IsBookmarked);
    }

    var items = await query
        .OrderByDescending(si => si.LastReadAtUtc)
        .Select(si => new ShelfItemDto(
            si.Id,
            si.StoryId,
            si.Story.Title,
            si.Story.Author,
            si.Story.Genre,
            si.ProgressPercentage,
            si.IsBookmarked,
            si.IsCompleted,
            si.LastReadAtUtc
        ))
        .ToListAsync();

    return Results.Ok(items);
});

// POST /api/v1/shelf/{storyId:guid}/toggle-bookmark
shelfGroup.MapPost("/{storyId:guid}/toggle-bookmark", async (Guid storyId, FableDbContext db) =>
{
    var story = await db.Stories.FindAsync(storyId);
    if (story is null) return Results.NotFound(new { message = "Story not found." });

    var item = await db.ShelfItems.FirstOrDefaultAsync(si => si.StoryId == storyId);
    if (item is null)
    {
        item = new ShelfItemEntity
        {
            Id = Guid.NewGuid(),
            StoryId = storyId,
            IsBookmarked = true,
            LastReadAtUtc = DateTime.UtcNow
        };
        db.ShelfItems.Add(item);
    }
    else
    {
        item.IsBookmarked = !item.IsBookmarked;
        item.LastReadAtUtc = DateTime.UtcNow;
    }

    await db.SaveChangesAsync();
    return Results.Ok(new { storyId, isBookmarked = item.IsBookmarked });
});

app.Run();
```

---

## 6. Containerization & Local Development (Docker Compose)

### 6.1 Backend Dockerfile (Multi-Stage Build)
```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ["Fable.Backend.csproj", "./"]
RUN dotnet restore "./Fable.Backend.csproj"

COPY . .
RUN dotnet publish "./Fable.Backend.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Fable.Backend.dll"]
```

### 6.2 docker-compose.yml
```yaml
version: '3.8'

services:
  fable-db:
    image: postgres:16-alpine
    container_name: fable-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: fable_db
      POSTGRES_USER: fable_user
      POSTGRES_PASSWORD: fable_dev_password
    ports:
      - "5432:5432"
    volumes:
      - fable_db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U fable_user -d fable_db"]
      interval: 5s
      timeout: 5s
      retries: 5

  fable-api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: fable-api
    restart: unless-stopped
    depends_on:
      fable-db:
        condition: service_healthy
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      ConnectionStrings__FableDatabase: "Host=fable-db;Port=5432;Database=fable_db;Username=fable_user;Password=fable_dev_password"
    ports:
      - "8080:8080"

volumes:
  fable_db_data:
```

---

## 7. iOS Client Architecture (SwiftUI + MVC)

The iOS client utilizes the standard Apple **Model–View–Controller (MVC)** architectural pattern optimized for SwiftUI and Swift 5.9+ / iOS 17+.

### 7.1 Architecture Component Responsibilities
- **Model (`Sources/Models/`):** Pure, immutable Swift `Codable` structs (`Story`, `Genre`, `ShelfItem`). Defines data structures, formatting helpers, and business domain logic.
- **Controller (`Sources/Controllers/`):** Centralized `@Observable` controller (`StoryController`). Holds business state, executes search/filter operations, manages optimistic updates, and coordinates data fetching.
- **Views (`Sources/Views/`):** Declarative SwiftUI components reacting strictly to properties published by the Controller. Views handle input events by delegating to controller methods.

```
       ┌────────────────────────────────────────────────────────────┐
       │                        VIEW LAYER                          │
       │                                                            │
       │  ┌──────────────────┐               ┌───────────────────┐  │
       │  │ StoryLibraryView │               │  StoryReaderView  │  │
       │  └────────┬─────────┘               └─────────┬─────────┘  │
       │           │                                   │            │
       │  ┌────────┴─────────┐               ┌─────────┴─────────┐  │
       │  │ StoryComposerView│               │  StoryShelfView   │  │
       │  └────────┬─────────┘               └─────────┬─────────┘  │
       └───────────┼───────────────────────────────────┼────────────┘
                   │ User Events (tap, submit, filter) │
                   │ Reads published observable state  │
                   ▼                                   ▼
       ┌────────────────────────────────────────────────────────────┐
       │                     CONTROLLER LAYER                       │
       │                                                            │
       │           ┌──────────────────────────────────────┐         │
       │           │      @Observable StoryController     │         │
       │           │                                      │         │
       │           │  - stories: [Story]                  │         │
       │           │  - selectedGenre: Genre              │         │
       │           │  - searchText: String                │         │
       │           │  - isOfflineMode: Bool               │         │
       │           │                                      │         │
       │           │  + toggleBookmark(for: Story)        │         │
       │           │  + addStory(title:author:...)        │         │
       │           │  + refreshStories() async            │         │
       │           └──────────────────┬───────────────────┘         │
       └──────────────────────────────┼─────────────────────────────┘
                                      │
            ┌─────────────────────────┴─────────────────────────┐
            ▼                                                   ▼
┌───────────────────────────────┐               ┌───────────────────────────────┐
│   MIDTERM: In-Memory Mock     │               │     FINAL: StoryAPIService    │
│   (Local sample collection)   │               │   (URLSession async/await)    │
└───────────────────────────────┘               └───────────────────────────────┘
```

### 7.2 Controller Implementation (Dual-Mode: Mock vs Live API)
```swift
import Foundation
import Observation

@Observable
public final class StoryController {
    public var stories: [Story] = []
    public var selectedGenre: Genre = .all
    public var searchText: String = ""
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    // Toggle between Midterm Mock Mode and Live REST API Mode
    public var isLiveBackendEnabled: Bool = false
    private let apiService: StoryAPIServiceProtocol

    public init(
        apiService: StoryAPIServiceProtocol = StoryAPIService(),
        isLiveBackendEnabled: Bool = false
    ) {
        self.apiService = apiService
        self.isLiveBackendEnabled = isLiveBackendEnabled
        
        if !isLiveBackendEnabled {
            loadMockStories()
        }
    }

    // Filtered stories computed property
    public var filteredStories: [Story] {
        stories.filter { story in
            let matchesGenre = (selectedGenre == .all || story.genre == selectedGenre)
            let matchesSearch = searchText.isEmpty ||
                story.title.localizedCaseInsensitiveContains(searchText) ||
                story.synopsis.localizedCaseInsensitiveContains(searchText)
            return matchesGenre && matchesSearch
        }
    }

    // Featured hero story
    public var featuredStory: Story? {
        stories.first
    }

    // Shelf collections
    public var bookmarkedStories: [Story] {
        stories.filter { $0.isBookmarked }
    }

    public var completedStories: [Story] {
        stories.filter { $0.isCompleted }
    }

    // Actions
    public func toggleBookmark(for story: Story) {
        guard let index = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[index].isBookmarked.toggle()

        if isLiveBackendEnabled {
            Task {
                try? await apiService.toggleBookmark(storyId: story.id)
            }
        }
    }

    public func addStory(
        title: String,
        author: String,
        genre: Genre,
        synopsis: String,
        content: String,
        readTimeMinutes: Int
    ) {
        let newStory = Story(
            id: UUID(),
            title: title,
            author: author.isEmpty ? "Anonymous" : author,
            genre: genre,
            synopsis: synopsis,
            content: content,
            readTimeMinutes: max(1, readTimeMinutes),
            isBookmarked: false,
            isCompleted: false,
            createdAtUtc: Date()
        )

        // Optimistic local insertion
        stories.insert(newStory, at: 0)

        if isLiveBackendEnabled {
            Task {
                let req = CreateStoryRequest(
                    title: title,
                    author: author,
                    genre: genre.rawValue,
                    synopsis: synopsis,
                    content: content,
                    readTimeMinutes: readTimeMinutes
                )
                try? await apiService.createStory(req)
            }
        }
    }

    public func refreshStories() async {
        guard isLiveBackendEnabled else { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await apiService.fetchStories(genre: selectedGenre.rawValue, search: searchText)
            self.stories = fetched
        } catch {
            self.errorMessage = "Failed to load stories: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // Midterm Seed Data (Aligning with Figma Prototype)
    private func loadMockStories() {
        self.stories = [
            Story(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                title: "The Balete Tree of Baler",
                author: "Danilo Ramos",
                genre: .folklore,
                synopsis: "Centuries-old roots cradle whispers of travelers who wandered past sundown.",
                content: "The ancient balete stood at the boundary between the cultivated rice terraces and the untouched canopy of Aurora. Its aerial roots were thicker than church pillars, twisting around a hollow core that emitted a cool, subterranean draft even in the scorching heat of April. Old man Mateo had warned every child in the barrio: 'When the cicadas abruptly cease their song at twilight, do not look into the hollow.' But Joel was seventeen, armed with modern skepticism and a pocket flashlight...",
                readTimeMinutes: 6,
                isBookmarked: true,
                isCompleted: false
            ),
            Story(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                title: "The Midnight Jeepney",
                author: "Maria Santos",
                genre: .urbanLegend,
                synopsis: "A commuter boards the last ride through Aurora Boulevard and discovers no one is paying with coins.",
                content: "Rain turned Epifanio de los Santos Avenue into a shimmering river of brake lights. It was 1:45 AM when the stainless-steel jeepney rattled to a halt beside the shuttered convenience store. The destination signboard bore no avenue or landmark, merely two words written in fading crimson script: 'SA DULO' (To the End). Sofia hopped onto the rear stirrup, shaking water from her umbrella...",
                readTimeMinutes: 4,
                isBookmarked: false,
                isCompleted: true
            ),
            Story(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                title: "Tears of the Diwata",
                author: "Alon Cruz",
                genre: .mythology,
                synopsis: "When the sacred lake dries, the guardian spirits demand an offering of forgotten songs.",
                content: "Before the miners carved terraces into Mount Makiling, the mountain was known to breathe. Its exhalations were mists scented with wild ginger and damp earth. Maria Makiling sat upon the basalt ridge, her long dark tresses trailing into the emerald waters of Lake Alligator...",
                readTimeMinutes: 8,
                isBookmarked: true,
                isCompleted: true
            ),
            Story(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                title: "Echoes on the Concrete Span",
                author: "R. Zaño",
                genre: .horror,
                synopsis: "Every year on the anniversary of the collapse, the radio picks up transmissions from cars that never made it across.",
                content: "The bridge connecting the two coastal towns had been completed in record time during the boom years of the late seventies. But local fishermen claimed that beneath the fifth pylon, the water never rippled naturally...",
                readTimeMinutes: 5,
                isBookmarked: false,
                isCompleted: false
            )
        ]
    }
}
```

### 7.3 iOS Networking Service (URLSession Async/Await)
```swift
import Foundation

public protocol StoryAPIServiceProtocol {
    func fetchStories(genre: String?, search: String?) async throws -> [Story]
    func createStory(_ request: CreateStoryRequest) async throws -> Story
    func toggleBookmark(storyId: UUID) async throws -> Bool
}

public final class StoryAPIService: StoryAPIServiceProtocol {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://localhost:8080/api/v1")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchStories(genre: String? = nil, search: String? = nil) async throws -> [Story] {
        var components = URLComponents(url: baseURL.appendingPathComponent("stories"), resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = []
        if let genre, genre != "All" { queryItems.append(URLQueryItem(name: "genre", value: genre)) }
        if let search, !search.isEmpty { queryItems.append(URLQueryItem(name: "search", value: search)) }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        let (data, response) = try await session.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let paged = try decoder.decode(PagedResult<Story>.self, from: data)
        return paged.items
    }

    public func createStory(_ request: CreateStoryRequest) async throws -> Story {
        let url = baseURL.appendingPathComponent("stories")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Story.self, from: data)
    }

    public func toggleBookmark(storyId: UUID) async throws -> Bool {
        let url = baseURL.appendingPathComponent("shelf/\(storyId)/toggle-bookmark")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct ToggleResponse: Codable { let isBookmarked: Bool }
        let result = try JSONDecoder().decode(ToggleResponse.self, from: data)
        return result.isBookmarked
    }
}
```

---

## 8. Screen Hierarchy & Figma Mapping

| Screen | Primary File | Core Components | Figma Tokens Mapped |
| :--- | :--- | :--- | :--- |
| **1. Library Feed** | `StoryLibraryView.swift` | Header with avatar, Genre pill carousel, Featured Hero card, Vertical story cards | Primary: `#2D2B2A`, Accent: `#D97736`, Card background: `#F8F6F0`, Typography: Serif headers |
| **2. Story Reader** | `StoryReaderView.swift` | Sticky top bar with back navigation, Bookmark button, Progress bar, Editorial reading body | Text size: 18pt, Line height: 1.6, Dynamic tint, Font: Georgia / New York serif |
| **3. Story Composer** | `StoryComposerView.swift` | Form inputs (Title, Author, Genre picker), Synopsis field, Manuscript editor, Word count badge | Form styling, Border radius: 12pt, Button: Terracotta fill with white text |
| **4. Story Shelf** | `StoryShelfView.swift` | Custom segmented control (Saved vs Finished), Compact collection rows, Progress chips | Background: `#FDFBF7`, Pill badges: `#EAE6DF` |

---

## 9. Phased Implementation Roadmap

```
  PHASE 1: MIDTERM DELIVERABLE (Deadline: Sept 17, 2026)
  ├─ [x] Project architecture & technology contract specification
  ├─ [ ] Standalone Swift Package / Playgrounds setup
  ├─ [ ] Models implementation (`Story.swift`, `Genre.swift`)
  ├─ [ ] Observable MVC Controller (`StoryController.swift`) with rich mock data
  ├─ [ ] 4 Core SwiftUI Views matching Figma layout & tokens:
  │    ├─ StoryLibraryView
  │    ├─ StoryReaderView
  │    ├─ StoryComposerView
  │    └─ StoryShelfView
  ├─ [ ] Root Navigation & TabView integration (`MainTabView.swift`)
  └─ [ ] Midterm review & visual inspection against Figma

  PHASE 2: BACKEND & DATABASE FOUNDATION
  ├─ [ ] Docker Compose orchestration (PostgreSQL 16)
  ├─ [ ] ASP.NET Core 8/9 Minimal APIs project initialization
  ├─ [ ] Entity Framework Core migrations & PostgreSQL database seed script
  ├─ [ ] Minimal API route endpoints (`/api/v1/stories`, `/api/v1/shelf`)
  └─ [ ] Verification via Swagger UI / Scalar

  PHASE 3: CLIENT-SERVER INTEGRATION
  ├─ [ ] Swift URLSession network client implementation (`StoryAPIService.swift`)
  ├─ [ ] Toggle `StoryController.isLiveBackendEnabled = true`
  ├─ [ ] Optimistic client updates & error toast notifications
  └─ [ ] Local networking configuration for iOS physical device testing

  PHASE 4: EXPANSION & ANDROID PARITY
  ├─ [ ] Port DTOs to Kotlin Data Classes
  ├─ [ ] Build Jetpack Compose UI matching identical design tokens
  └─ [ ] Wire Kotlin ViewModel to same ASP.NET Core REST API
```