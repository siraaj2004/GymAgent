import Foundation

/// Built-in Help Chat answers. These are troubleshooting steps, not a live
/// support agent. An installed app cannot fix its own code — if a workaround
/// does not solve the problem, the complaint is marked Escalated with a
/// summary for the developer, to be fixed in the next app version (new IPA).
enum HelpAssistant {
    static func solution(for message: String) -> String {
        let m = message.lowercased()
        if m.contains("camera") || m.contains("detect") || m.contains("count") || m.contains("rep") {
            return "Camera help: 1) Place the phone so the joints for that exercise are fully in frame (the app shows guidance for each exercise). 2) Use good light, plain background. 3) Move slowly through the full movement — half reps never count. 4) If it still says 'Unable to assess', tap '+1 rep by hand' — manual counting always works."
        }
        if m.contains("voice") || m.contains("speak") || m.contains("sound") || m.contains("telugu") {
            return "Voice help: 1) Check the Mute toggle is OFF in AI Coach. 2) Turn up phone volume and check Bluetooth earphones are connected if you use them. 3) Set trainer language in onboarding to Telugu for Telugu corrections (Mixed Telugu and English also works). 4) If a Telugu clip is missing, the app falls back to the iPhone Telugu voice."
        }
        if m.contains("notif") || m.contains("remind") {
            return "Reminder help: 1) Allow Notifications in iPhone Settings > GYM AI. 2) Check your gym time is correct in your profile. 3) On rest days the app only sends a recovery message, not a workout reminder — that is by design."
        }
        if m.contains("install") || m.contains("sideload") || m.contains("expir") || m.contains("open") || m.contains("crash") {
            return "Install help: This is an unsigned IPA for Sideloadly / AltStore with a free Apple ID, so it expires after 7 days — reinstall it weekly. If it will not open after expiry, reinstall the latest ios.ipa. If it crashes on open, delete it and reinstall; if it still crashes, tap 'Still not solved' so the problem is recorded for the next version."
        }
        if m.contains("food") || m.contains("protein") || m.contains("calorie") {
            return "Food help: 1) Search the food name in Food, tap Add, and correct the grams if your portion is different. 2) Your targets come from your weight, height, age, activity and goal in onboarding — change those in your profile to change targets. 3) For cheap protein, open the Low-price nutrition card in Food and pick Low-cost foods like soya chunks, dal, eggs and milk."
        }
        if m.contains("workout") || m.contains("plan") || m.contains("exercise") {
            return "Workout help: 1) Home shows today's day automatically (Monday = Day 1 … Friday = Day 5, weekend = rest). 2) You can also pick any day in Workout. 3) Exercises are grouped by time block totalling 100 minutes. 4) Tap 'Tap when done' after each set, even if the camera did not count it."
        }
        return "Thanks — I have recorded this. Try these first: 1) Close and reopen the app. 2) Check Camera / Notification permissions in iPhone Settings > GYM AI. 3) If the problem is with one exercise, use manual counting for that exercise. If none of that helps, tap 'Still not solved' and your complaint will be marked for fixing in the next app version."
    }
}
