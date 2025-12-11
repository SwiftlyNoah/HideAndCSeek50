# Question Reward System Updates

## Overview

The question reward system has been updated to store rewards in the `QuestionData` structure and to double rewards for questions that have been asked before.

## Changes Made

### 1. QuestionData Structure (Game.swift)

Added reward fields directly to `QuestionData`:

```swift
struct QuestionData: Codable {
    let questionId: String
    let questionText: String
    var isAnswered: Bool = false
    var playerAnswer: String?
    var questionCategory: QuestionCategory? = nil
    var drawCount: Int = 1        // NEW
    var keepCount: Int = 1         // NEW
    
    var rewardDescription: String {  // NEW
        "Draw \(drawCount), Keep \(keepCount)"
    }
}
```

**Benefits:**
- Rewards are stored with each question
- Allows for dynamic reward calculations
- Persists in database with the question
- Supports doubling mechanism

### 2. Question Sending Logic (QuestionView.swift)

#### Updated `sendQuestion()` function:

**Before:**
- Appended reward text to question content
- Used static reward from category

**After:**
- Question content is clean (no reward text)
- Calculates reward dynamically based on history
- Doubles reward if question was asked before
- Shows confirmation message indicating if reward was doubled

#### New Helper Functions:

**`calculateReward(for:)`**
- Parses base reward from category
- Checks if question was asked before
- Returns doubled values if duplicate

**`checkIfQuestionAskedBefore(_:)`**
- Searches all game messages
- Compares question text exactly
- Returns true if found in history

**`parseReward(_:)`**
- Parses "Draw X, Keep Y" format
- Extracts draw and keep counts
- Returns tuple with values

### 3. Visual Indicators for Asked Questions

#### Question Selector UI Updates:

**Legend:**
- Green checkmark: Question has been asked
- Orange arrow: Reward will be doubled

**Question Cards:**
- Orange tint for previously asked questions
- Badge showing both icons
- Caption: "Asked before — Reward will be doubled!"
- Orange border for emphasis

**Example:**
```
┌──────────────────────────────────┐
│ Commercial Airport ✓ ↑           │
│ Asked before — Reward doubled!   │
└──────────────────────────────────┘
```

### 4. Chat Display Updates (GameChatView.swift)

#### Reward Button:
- Shows `questionData.rewardDescription`
- Displays actual reward values (not category default)
- Examples:
  - "Draw 3, Keep 1" (first time)
  - "Draw 6, Keep 2" (asked before)

#### Reward Claiming:
- Uses `questionData.drawCount` and `questionData.keepCount`
- Creates `DrawAction` from question data
- Passes actual values to card system

### 5. Database Structure

Questions now store complete reward info:

```json
{
  "questionData": {
    "questionId": "uuid",
    "questionText": "Is your nearest Airport the same as mine?",
    "questionCategory": "matching",
    "drawCount": 3,
    "keepCount": 1,
    "isAnswered": false
  }
}
```

## Reward Doubling Logic

### When Does Doubling Occur?

A reward is doubled when:
1. The exact question text has been asked before
2. In the same game session
3. Regardless of when it was asked

### Examples:

**First Time:**
- Question: "Is your nearest Airport the same as mine?"
- Category: Matching
- Reward: Draw 3, Keep 1

**Second Time (Same Question):**
- Question: "Is your nearest Airport the same as mine?"
- Category: Matching
- Reward: Draw 6, Keep 2 ✨ (DOUBLED)

**Different Question:**
- Question: "Is your nearest Transit Line the same as mine?"
- Category: Matching
- Reward: Draw 3, Keep 1 (Not doubled - different question)

### Calculation Formula:

```swift
if previouslyAsked {
    drawCount = baseDrawCount * 2
    keepCount = baseKeepCount * 2
} else {
    drawCount = baseDrawCount
    keepCount = baseKeepCount
}
```

## User Experience Flow

### For Seekers:

1. **Open Question View**
   - Select category
   - See list of questions

2. **Previously Asked Questions**
   - Highlighted with orange tint
   - Show checkmark and arrow icons
   - Display "Asked before — Reward will be doubled!"

3. **Send Question**
   - If duplicate: Success message says "Reward doubled since this was asked before"
   - If new: Standard success message

4. **View in Chat**
   - Question displays without reward text appended
   - Clean question content

5. **When Answered**
   - Reward button shows actual values
   - "Draw 6, Keep 2" instead of "Draw 3, Keep 1" if doubled

6. **Claim Reward**
   - Correct number of cards drawn
   - Proper selection interface

### For Hiders:

1. **See Question in Chat**
   - Clean question text
   - No reward information visible

2. **Answer Question**
   - Standard answer interface
   - No knowledge of reward amount

## Benefits of This System

### 1. **Flexibility**
- Each question has its own reward
- Can be modified per question if needed
- Not tied to category defaults

### 2. **Strategic Gameplay**
- Incentivizes asking unique questions
- Rewards exploration of question variety
- But allows re-asking for double rewards

### 3. **Data Integrity**
- Rewards stored with question
- No calculation needed on retrieval
- Persists in database

### 4. **User Awareness**
- Visual indicators show which questions were asked
- Clear feedback on doubling
- Transparent reward system

### 5. **Clean UI**
- Question text is clean (no appended reward)
- Reward shown in dedicated button
- Better separation of concerns

## Testing Recommendations

### Test Cases:

1. **First Time Question**
   - Ask any question
   - Verify base reward shown
   - Claim and verify correct card count

2. **Duplicate Question**
   - Ask same question again
   - Verify orange highlight
   - Verify doubled reward displayed
   - Claim and verify doubled cards

3. **Different Questions Same Category**
   - Ask "Airport" from Matching
   - Ask "Transit Line" from Matching
   - Verify first gets base reward
   - Verify second gets base reward (not doubled)

4. **Re-asking After Several Questions**
   - Ask "Airport"
   - Ask several other questions
   - Ask "Airport" again
   - Verify doubling still occurs

5. **Visual Indicators**
   - Check orange tint appears
   - Verify checkmark and arrow icons
   - Verify caption text shows

6. **Chat Display**
   - Question text is clean
   - Reward button shows correct values
   - Doubled values display properly

7. **Card Drawing**
   - Draw 3, Keep 1 works
   - Draw 6, Keep 2 works (doubled)
   - All reward combinations work

## Edge Cases Handled

1. **Empty Game History**
   - First question always gets base reward
   - No errors when checking history

2. **Multiple Duplicates**
   - Each instance gets doubled reward
   - No limit on duplicates

3. **Case Sensitivity**
   - Exact text match required
   - "Airport" ≠ "airport"

4. **Category Changes**
   - Same question text, different category treated as different
   - Question text includes category context

5. **Timing**
   - Only past questions considered
   - Current question not compared with itself

## Future Enhancements

Possible improvements:

1. **Tripling for Third+ Asking**
   - 3rd time: 3x reward
   - 4th time: 4x reward, etc.

2. **Cooldown Period**
   - Can't re-ask within X minutes
   - Prevents spam

3. **Diminishing Returns**
   - 2nd time: 2x
   - 3rd time: 1.5x
   - 4th time: 1.25x

4. **Question Statistics**
   - Show how many times asked
   - Show when last asked
   - Show total rewards earned

5. **Team Sharing**
   - All seekers benefit from any seeker's questions
   - Shared question history

6. **Hider Awareness**
   - Show hiders if question was asked before
   - Different answer UI for repeated questions

## Migration Notes

### Existing Games:

Old questions without reward fields will:
- Default to drawCount: 1, keepCount: 1
- Still display in chat
- Work with answer system
- May need manual reward assignment if claimed

### New Games:

All questions will have:
- Proper reward values
- Doubling detection
- Full visual indicators
- Complete data structure

## Code Locations

### Modified Files:
1. **Game.swift** - QuestionData structure
2. **QuestionView.swift** - Reward calculation and UI
3. **GameChatView.swift** - Reward display and claiming

### Key Functions:
- `calculateReward(for:)` - Reward calculation
- `checkIfQuestionAskedBefore(_:)` - Duplicate detection
- `parseReward(_:)` - Reward parsing
- `questionSelector(questions:)` - Visual indicators
- `handleClaimReward(_:)` - Reward claiming

## Summary

This update transforms the reward system from a static, category-based approach to a dynamic, question-based system that:

✅ Stores rewards with each question
✅ Doubles rewards for duplicate questions
✅ Provides clear visual feedback
✅ Maintains clean question text
✅ Integrates seamlessly with card system
✅ Encourages strategic question selection
✅ Rewards both variety and repetition
