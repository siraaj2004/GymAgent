import Foundation

/// Help Chat answers, fixed for relevance.
///
/// THE OLD PROBLEM: the old code checked topics in a fixed order and stopped
/// at the FIRST keyword it found. So a question like "my food protein count
/// is wrong" could hit the camera answer (because of the word "count"),
/// and a question with no exact keyword got a vague generic answer.
/// That is why answers felt unrelated ("unsink" / out of sync with the
/// question).
///
/// THE FIX: every topic is SCORED against the whole question. Strong words
/// count 2, weak words count 1, and the topic with the highest score wins.
/// Example: "count calories" scores Food 2 + Camera 1, so Food wins.
/// "count reps" scores Camera 2 + 1, so Camera wins. Ties keep the topic
/// whose strong word appeared first. If no topic scores at all, the answer
/// does not pretend to know — it asks which topic the problem is about and
/// lists the exact words to type, so the next answer is relevant.
///
/// Honest limit, unchanged: an installed app cannot fix its own code.
/// A workaround that works = Solved. A real bug = Escalated for the next
/// app version (new IPA).
enum HelpAssistant {
    private struct Topic {
        var strong: [String]
        var weak: [String]
        var answer: String
    }

    private static let topics: [Topic] = [
        Topic(
            strong: ["camera", "rep", "reps", "pose", "skeleton", "detect"],
            weak: ["count", "counting", "frame", "visible", "blur", "dark", "light"],
            answer: "Camera help: 1) Place the phone so the joints for that exercise are fully in frame — the app shows the phone position for each exercise. 2) Use good light and a plain background. 3) Move slowly through the FULL movement — half reps never count, that is by design. 4) If it still says 'Unable to assess', tap '+1 rep by hand' for that rep — manual counting always works."
        ),
        Topic(
            strong: ["voice", "speak", "sound", "telugu", "audio"],
            weak: ["mute", "volume", "earphone", "listen", "hear"],
            answer: "Voice help: 1) Check the Mute toggle is OFF in AI Coach. 2) Turn up phone volume, and check Bluetooth earphones if you use them. 3) For Telugu corrections, set trainer language to Telugu in onboarding (Mixed Telugu and English also works). 4) If a Telugu clip is missing, the app falls back to the iPhone Telugu voice."
        ),
        Topic(
            strong: ["notification", "reminder", "remind", "notify"],
            weak: ["alert", "gym time", "snooze"],
            answer: "Reminder help: 1) Allow Notifications in iPhone Settings > GYM AI. 2) Check your gym time is correct in your profile. 3) On rest days (Saturday/Sunday) the app only sends a recovery message, not a workout reminder — that is by design. 4) If a reminder still does not come, tap 'Snooze 10 min' on Home once, then check again tomorrow."
        ),
        Topic(
            strong: ["crash", "install", "sideload", "expire", "expiry", "open"],
            weak: ["download", "altstore", "app store", "blank", "freeze", "stuck", "error"],
            answer: "Install help: This is an unsigned IPA for Sideloadly / AltStore with a free Apple ID, so it expires after 7 days — reinstall it weekly. If it will not open after expiry, reinstall the latest ios.ipa. If it crashes on open, delete it and reinstall; if it still crashes, tap 'Still not solved' so the problem is recorded for the next version."
        ),
        Topic(
            strong: ["food", "protein", "carb", "calorie", "nutrition", "fibre", "fiber", "diet", "meal"],
            weak: ["eat", "dal", "rice", "weight loss", "weight gain"],
            answer: "Food help: 1) Search the food name in Food, tap Add, and correct the grams if your portion is different — the values are estimates for the stated serving. 2) Your protein / carbs / fibre targets come from your weight, height, age, activity and goal in onboarding. 3) For cheap protein, open the Low-price nutrition card in Food and pick Low-cost foods like soya chunks, dal, eggs and milk."
        ),
        Topic(
            strong: ["workout", "exercise", "plan", "day"],
            weak: ["set", "sets", "schedule", "monday", "tuesday"],
            answer: "Workout help: 1) Home shows today's day automatically (Monday = Day 1 … Friday = Day 5, weekend = rest). 2) You can also pick any day in Workout. 3) Exercises are grouped by time block totalling 100 minutes. 4) Tap 'Tap when done' after each set, even if the camera did not count it."
        ),
        Topic(
            strong: ["progress", "weight", "chart", "history"],
            weak: ["record", "saved", "tracking"],
            answer: "Progress help: 1) Progress shows workouts completed, total volume (reps x weight of saved sets), heaviest saved set, and your saved weights. 2) A workout only counts as completed when you tap 'End workout & save' in Workout. 3) To save a new weight, type it in Progress and tap Save. 4) If a past workout is missing, it was not saved with 'End workout & save' — that cannot be recovered afterwards."
        ),
        Topic(
            strong: ["profile", "onboarding", "age", "height", "goal"],
            weak: ["name", "setup", "change"],
            answer: "Profile help: 1) Your weight, height, age, activity and goal are set once in onboarding, and they decide your calorie, protein, carbs and fibre targets. 2) If a target looks wrong, check those onboarding values first — a wrong weight or height gives a wrong target. 3) If you need to change them, complete onboarding again with the correct values."
        ),
    ]

    static func solution(for message: String) -> String {
        let m = message.lowercased()
        var bestScore = 0
        var bestAnswer: String?
        for topic in topics {
            var score = 0
            for word in topic.strong where m.contains(word) { score += 2 }
            for word in topic.weak where m.contains(word) { score += 1 }
            if score > bestScore { bestScore = score; bestAnswer = topic.answer }
        }
        if let answer = bestAnswer { return answer }
        return "I could not match that to one problem, so I will not guess an unrelated answer. Please tell me which one it is, in one word: camera, voice, reminder, install, food, workout, progress, or profile — or tap one of the topic buttons above. Then I will give you the exact fix steps for that problem."
    }
}
