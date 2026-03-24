# Data Models

## Room Database Schema

### Entity: Novel

```kotlin
@Entity(tableName = "novels")
data class Novel(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,                    // e.g., "Pet Sematary"
    val sourceLanguage: String,          // e.g., "ja"
    val targetLanguage: String,          // e.g., "en"
    val createdAt: Long,                 // epoch millis
    val sortOrder: Int = 0              // for manual reordering
)
```

### Entity: WordEntry

```kotlin
@Entity(
    tableName = "word_entries",
    foreignKeys = [ForeignKey(
        entity = Novel::class,
        parentColumns = ["id"],
        childColumns = ["novelId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("novelId")]
)
data class WordEntry(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val novelId: Long,                   // FK to Novel
    val selectedText: String,            // the word/phrase as scanned
    val surroundingContext: String,       // the sentence it appeared in
    val explanationJson: String,         // full AI response cached as JSON
    val createdAt: Long                  // epoch millis
)
```

### Parsed Explanation (not stored as entity — parsed from JSON)

```kotlin
data class Explanation(
    val meaning: String?,
    val reading: String?,
    val context: String?,
    val examples: List<String>?,
    val breakdown: String?,
    val formality: String?,
    val similarWords: List<SimilarWord>?
)

data class SimilarWord(
    val word: String,
    val reading: String,
    val brief: String
)
```

### Entity: Comparison (cached comparisons)

```kotlin
@Entity(
    tableName = "comparisons",
    indices = [Index("wordEntryId")]
)
data class Comparison(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val wordEntryId: Long,              // FK to the original WordEntry
    val originalWord: String,
    val comparedWord: String,
    val comparisonJson: String,         // full AI comparison response
    val createdAt: Long
)
```

---

## DAOs

### NovelDao

```kotlin
@Dao
interface NovelDao {
    @Query("SELECT * FROM novels ORDER BY sortOrder ASC, createdAt DESC")
    fun getAllNovels(): Flow<List<Novel>>

    @Insert
    suspend fun insert(novel: Novel): Long

    @Update
    suspend fun update(novel: Novel)

    @Query("DELETE FROM novels WHERE id = :id")
    suspend fun deleteById(id: Long)
}
```

### WordEntryDao

```kotlin
@Dao
interface WordEntryDao {
    @Query("SELECT * FROM word_entries WHERE novelId = :novelId ORDER BY createdAt DESC")
    fun getEntriesByNovel(novelId: Long): Flow<List<WordEntry>>

    @Query("SELECT * FROM word_entries WHERE novelId = :novelId AND selectedText LIKE '%' || :query || '%'")
    fun searchEntries(novelId: Long, query: String): Flow<List<WordEntry>>

    @Insert
    suspend fun insert(entry: WordEntry): Long

    @Query("DELETE FROM word_entries WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("DELETE FROM word_entries")
    suspend fun deleteAll()
}
```

---

## API DTOs

### OpenAI Request (simplified)

```kotlin
data class ChatRequest(
    val model: String = "gpt-4o-mini",
    val messages: List<Message>,
    val response_format: ResponseFormat = ResponseFormat("json_object")
)

data class Message(
    val role: String,  // "system" or "user"
    val content: String
)

data class ResponseFormat(
    val type: String
)
```

### OpenAI Response (simplified, relevant fields only)

```kotlin
data class ChatResponse(
    val choices: List<Choice>
)

data class Choice(
    val message: MessageContent
)

data class MessageContent(
    val content: String  // JSON string to parse into Explanation
)
```

---

## Settings (DataStore / EncryptedSharedPreferences)

```kotlin
data class AppSettings(
    val openAiApiKey: String = "",
    val defaultSourceLanguage: String = "ja",
    val defaultTargetLanguage: String = "en",
    val enabledCategories: Set<ExplanationCategory> = ExplanationCategory.values().toSet()
)

enum class ExplanationCategory {
    MEANING,
    READING,
    CONTEXT,
    EXAMPLES,
    BREAKDOWN,
    FORMALITY,
    SIMILAR_WORDS
}
```
